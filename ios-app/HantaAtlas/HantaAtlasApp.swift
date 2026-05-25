import SwiftUI

@main
struct HantaAtlasApp: App {
    #if DEBUG
    private let debugFirstRunResetApplied = DevelopmentFirstRunReset.applyIfNeeded()
    #endif

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("hasCompletedStartupPermissions") private var hasCompletedStartupPermissions: Bool = false

    /// Starts mounting the real host after `LaunchSplashView` finishes its
    /// calibration sequence (≈1.3s) or the user taps to skip. `@State` (not
    /// `@AppStorage`) on purpose — we want the splash every cold launch, not
    /// just the first install.
    @State private var hasStartedHostContent: Bool = false

    /// Keeps the splash visible until the host has actually appeared. Mapbox
    /// and SwiftUI cold/debug launches can delay the first host frame; removing
    /// the splash before that point exposes a paper-only white screen.
    @State private var hasDismissedLaunchSplash: Bool = false

    init() {
        LaunchTrace.checkpoint("HantaAtlasApp.init")
    }

    /// Force light mode at the WindowGroup level. Without this, iOS 26
    /// briefly applies the system's `.systemBackground` while the SwiftUI
    /// window mounts — on dark-mode-following devices that flashed black
    /// for ~5–10s during cold-start glass-shader compilation. Forcing
    /// `.light` paints `Theme.paper`-equivalent immediately so the user
    /// never sees the void. Map content keeps its dark treatment via a
    /// scoped `.environment(\.colorScheme, .dark)` on the Map view only.
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Always-visible warm backdrop. Painted under everything,
                // immediately, so the first frame is paper-ivory rather
                // than the system void. This is the single biggest
                // contributor to "no black screen on boot".
                Theme.paper.ignoresSafeArea()

                // Keep host construction out of the splash animation window,
                // then briefly overlap the resolved splash over the host until
                // SwiftUI reports the real first screen appeared. This avoids
                // both failure modes: early heavy host work freezing the splash,
                // and the splash disappearing into a paper-only blank frame.
                if hasStartedHostContent {
                    hostContent
                        .transition(.opacity)
                        .onAppear {
                            guard !hasDismissedLaunchSplash else { return }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation(.easeOut(duration: 0.30)) {
                                    hasDismissedLaunchSplash = true
                                }
                            }
                        }
                }

                if !hasDismissedLaunchSplash {
                    LaunchSplashView {
                        hasStartedHostContent = true
                    }
                    // Once the real first-run surface starts mounting, the
                    // splash is visual-only. This prevents a delayed crossfade
                    // from swallowing the onboarding/auth Continue taps on
                    // slower iPad debug or review launches.
                    .allowsHitTesting(!hasStartedHostContent)
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .preferredColorScheme(.light)
            .task(priority: .userInitiated) {
                LaunchTrace.checkpoint("WindowGroup.task begin")
                // Restore any cached Sign in with Apple / email session from
                // the Keychain. Runs off the first-frame path (Keychain reads
                // can block on first access). No longer gates the UI — it lets
                // a returning signed-in user be recognised so their profile can
                // sync.
                await LaunchTrace.span("UserSession.rehydrate") {
                    await UserSession.shared.rehydrate()
                }
                // Pull the per-user profile (saved countries + settings) for an
                // already-signed-in user. No-op when signed out.
                await PreferencesSync.shared.syncOnLaunch()
                LaunchTrace.checkpoint("WindowGroup.task end")
            }
            .task(id: hasCompletedOnboarding) {
                guard hasCompletedOnboarding else { return }
                ContentCachePrewarmer.schedule()
            }
        }
    }

    /// Permissions → Onboarding → Content flow switcher. The app is fully
    /// browsable without an account; sign-in is requested **contextually** by
    /// `AuthGate` only when the user invokes a profile action (save a country,
    /// open Profile, change alert settings). This is the App Review-safe
    /// pattern under Guideline 5.1.1(v) — non-account features are reachable
    /// before login. Session rehydrate still runs at launch (off the
    /// first-frame path) so a returning signed-in user is recognised and their
    /// profile syncs, but it no longer gates the UI.
    ///
    /// Decision matrix:
    ///   startup permissions incomplete → StartupPermissionsView
    ///   onboarding incomplete          → OnboardingView
    ///   otherwise                      → ContentView
    @ViewBuilder
    private var hostContent: some View {
        switch AppStartupRoute.resolve(
            hasCompletedStartupPermissions: hasCompletedStartupPermissions,
            hasCompletedOnboarding: hasCompletedOnboarding
        ) {
        case .startupPermissions:
            StartupPermissionsView()
                .transition(.opacity)
        case .onboarding:
            OnboardingView()
                .transition(.opacity)
        case .content:
            ContentView()
                .transition(.opacity)
        }
    }
}

/// Pure routing decision for the cold-start gate chain. Extracted so the
/// ordering (permissions → onboarding → content) is unit-testable and lives in
/// exactly one place. Auth is intentionally absent here — it is contextual,
/// driven by `AuthGate`, not a startup gate.
enum AppStartupRoute: Equatable {
    case startupPermissions
    case onboarding
    case content

    static func resolve(
        hasCompletedStartupPermissions: Bool,
        hasCompletedOnboarding: Bool
    ) -> AppStartupRoute {
        guard hasCompletedStartupPermissions else { return .startupPermissions }
        guard hasCompletedOnboarding else { return .onboarding }
        return .content
    }
}

@MainActor
private enum ContentCachePrewarmer {
    private static var didSchedule = false

    static func schedule() {
        guard !didSchedule else { return }
        didSchedule = true

        Task.detached(priority: .utility) {
            _ = Fixtures.summary
            _ = Fixtures.countries
            _ = Fixtures.alerts
            _ = Fixtures.guideArticles
            _ = Fixtures.mapCountries
            _ = Fixtures.signals
            _ = Fixtures.signalAggregates
            _ = Fixtures.stats

            // This warms the country catalogue away from the first-run
            // onboarding path. Returning users still get the cached catalogue
            // before most content surfaces need it, without risking a white
            // launch screen during App Review's clean install flow.
            _ = CountryCatalogue.merged(with: Fixtures.countries)
        }
    }
}

#if DEBUG
/// One-shot local reset used while validating the App Review onboarding fix.
/// This clears UserDefaults before SwiftUI reads
/// `@AppStorage("hasCompletedOnboarding")`.
private enum DevelopmentFirstRunReset {
    private static let tokenKey = "hantaatlas.debug.firstRunResetToken"
    private static let tokenValue = "2026-05-14-ipad-onboarding-review-v1"

    @discardableResult
    static func applyIfNeeded(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.string(forKey: tokenKey) != tokenValue else { return false }

        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleIdentifier)
        }

        // Also clear the Keychain session — it survives a UserDefaults wipe
        // (and app reinstalls), so without this a "first run" debug reset
        // would skip the auth gate and land straight on ContentView.
        KeychainStore.clearAll()

        defaults.set(tokenValue, forKey: tokenKey)
        defaults.synchronize()
        return true
    }
}
#endif

import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case today
    case map
    case feed
    case alerts

    var title: String {
        switch self {
        case .today:  "Today"
        case .map:    "Map"
        case .feed:   "Feed"
        case .alerts: "Alerts"
        }
    }

    var symbolName: String {
        switch self {
        case .today:  "globe.europe.africa"
        case .map:    "map"
        case .feed:   "list.bullet.rectangle"
        case .alerts: "bell.badge"
        }
    }
}

struct ContentView: View {
    @State private var repository: SurveillanceRepository = {
        LaunchTrace.sync("SurveillanceRepository.init") { SurveillanceRepository() }
    }()
    /// Shared so the contextual-auth profile sync (`PreferencesSync`) mutates
    /// the same instance the whole UI binds to.
    @State private var preferences = LocalPreferences.shared
    @State private var selectedTab: AppTab = .today

    /// Contextual sign-in: the gate presents `WelcomeView` as a sheet when a
    /// profile action needs an account; the session drives fulfilment + sync.
    @State private var authGate = AuthGate.shared

    @State private var session = UserSession.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(repository: repository, preferences: preferences)
                    // Lock the tab-bar backdrop to a stable solid material
                    // on light-content pages. Without this, iOS 26's adaptive
                    // Liquid Glass flickers between the dark/light glass when
                    // switching from the Map tab back to a paper page.
                    .toolbarBackground(.visible, for: .tabBar)
            }
            .tabItem { Label(AppTab.today.title, systemImage: AppTab.today.symbolName) }
            .tag(AppTab.today)

            NavigationStack {
                WorldMapView(repository: repository, preferences: preferences)
                // Map keeps the default: fully transparent Liquid Glass
                // over the dark map content, as the user requested.
            }
            .tabItem { Label(AppTab.map.title, systemImage: AppTab.map.symbolName) }
            .tag(AppTab.map)

            NavigationStack {
                OutbreakFeedView(
                    repository: repository,
                    preferences: preferences,
                    onCaughtUp: {
                        // Closes the catch-up loop: when the swipe
                        // deck reaches "all caught up", auto-return
                        // the user to the Today summary instead of
                        // leaving them on the empty Feed surface.
                        // Plain assignment — wrapping a TabView selection change
                        // in withAnimation can animate the internal horizontal
                        // tab layout and leave content translated/clipped.
                        selectedTab = .today
                    }
                )
                .toolbarBackground(.visible, for: .tabBar)
            }
            .tabItem { Label(AppTab.feed.title, systemImage: AppTab.feed.symbolName) }
            .tag(AppTab.feed)

            NavigationStack {
                AlertsView(repository: repository, preferences: preferences)
                    .toolbarBackground(.visible, for: .tabBar)
            }
            .tabItem { Label(AppTab.alerts.title, systemImage: AppTab.alerts.symbolName) }
            .tag(AppTab.alerts)
        }
        .tint(Theme.terracotta)
        // NOTE: do not put `.animation(_:value:)` on this TabView. TabView lays
        // its tab roots out horizontally; a container-wide implicit animation
        // animates that internal x-repositioning, so a state flip mid-animation
        // (refresh toggling `hasLoadedFromNetwork`, a Both/Hanta/Ebola switch,
        // or returning to a tab) left the whole page translated and clipped
        // while the tab bar stayed put. The skeleton↔content fade is owned by
        // DashboardView (scoped to `isInitialLoading`), so no animation is
        // needed here.
        // Contextual sign-in sheet — presented by AuthGate.require(...) from any
        // profile action. Bound here, once, at the app root.
        .sheet(isPresented: $authGate.isPresentingSignIn) {
            WelcomeView(context: .sheet, onClose: { authGate.cancel() })
        }
        // When sign-in succeeds: run the deferred profile action and sync the
        // user's saved countries + settings from/to the backend profile.
        .onChange(of: session.isAuthenticated) { _, signedIn in
            guard signedIn else { return }
            authGate.fulfilPendingIfAuthenticated()
            Task { await PreferencesSync.shared.syncOnSignIn() }
        }
        .task(id: preferences.selectedDiseaseMode) {
            LaunchTrace.checkpoint("ContentView.task begin")
            await repository.refresh(preferences: preferences)
            LaunchTrace.checkpoint("repository.refresh end")
            LaunchTrace.checkpoint("ContentView.task end")
        }
    }
}

#Preview("Light") {
    ContentView()
}

#Preview("Dark") {
    ContentView()
        .preferredColorScheme(.dark)
}

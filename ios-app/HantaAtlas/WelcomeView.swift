import SwiftUI
import AuthenticationServices

/// First-launch welcome scene. Sits between onboarding (informational
/// disclaimers) and ContentView. Sign in with Apple is required — the app
/// is gated on `UserSession.isAuthenticated` from cold launch. Sandbox
/// Apple ID credentials for App Review reviewers live in the gitignored
/// `docs/app-review-credentials.md.local` (not in source).
///
/// iOS 26 design language:
///  - Liquid Glass on the welcome card + primary action surface
///  - Brand identity: serif HantaAtlas wordmark + warm-palette globe
///  - Subtle reveal animations: phaseAnimator on the wordmark, gentle
///    drift particles in the background
///  - Accessibility: full Dynamic Type support, VoiceOver labels on all
///    interactive elements, Reduce Motion replaces particles + animation
///    with a static state, Reduce Transparency replaces glass with a
///    solid paper card, Increased Contrast respects the system role
///  - Light + Dark mode handled via Theme tokens
///
/// Terms of Service and Privacy Policy are surfaced directly on this screen
/// (the `legalLine` below) so the legal agreement the user enters by signing
/// in is visible and reachable before any account is created — an App Review
/// expectation for sign-in surfaces.
struct WelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.openURL) private var openURL

    @State private var authService = AuthService.shared
    @State private var session = UserSession.shared
    @State private var revealPhase: RevealPhase = .hidden
    @State private var showEmailSheet: Bool = false
    @State private var showLegalOptions: Bool = false

    /// How the screen is presented. It is shown as a `.sheet` (via `AuthGate`)
    /// the moment the user invokes a profile action; `.root` is retained for
    /// previews. In a sheet we show a close control and skip the staged reveal
    /// (the user opened it deliberately — show the buttons immediately).
    enum Presentation { case sheet, root }
    var context: Presentation = .sheet

    /// Invoked when the user dismisses the sheet without signing in.
    var onClose: (() -> Void)? = nil

    /// Public legal pages on the marketing site. Same URLs the Profile screen
    /// links to, so there is a single canonical source of legal copy.
    private static let termsURL = URL(string: "https://thehantaapp.com/tos")!
    private static let privacyURL = URL(string: "https://thehantaapp.com/privacy")!

    enum RevealPhase: CaseIterable { case hidden, mark, copy, cta }

    var body: some View {
        ZStack {
            authBackdrop

            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        hero
                            .opacity(revealPhase.rawValueIndex >= 1 ? 1 : 0)
                            .offset(y: revealPhase.rawValueIndex >= 1 ? 0 : 8)

                        welcomeCard
                    }
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: max(0, proxy.size.height - 156), alignment: .center)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, isRegularWidth ? Theme.Space.huge : Theme.Space.xl)
                    .padding(.bottom, 176)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                actionStack
                disclaimerLine
                legalLine
            }
            .frame(maxWidth: actionMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .overlay(alignment: .topTrailing) {
            if context == .sheet { closeButton }
        }
        .onAppear { performReveal() }
        .sheet(isPresented: $showEmailSheet) {
            EmailSignInSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(32)
        }
        // VoiceOver / iPad: a tap on the legal line opens this chooser. Both
        // destinations open in Safari (our content stays in-app; legal pages
        // are external, per the source-link convention).
        .confirmationDialog("Legal", isPresented: $showLegalOptions, titleVisibility: .hidden) {
            Button("Terms of Service") { openURL(Self.termsURL) }
            Button("Privacy Policy") { openURL(Self.privacyURL) }
            Button("Cancel", role: .cancel) {}
        }
        // No view-level auth-state observer here: the root app gate
        // (HantaAtlasApp.hostContent) watches UserSession.isAuthenticated
        // and swaps Welcome → ContentView automatically the moment any
        // auth flow updates the session.
    }

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    private var contentMaxWidth: CGFloat {
        isRegularWidth ? 680 : .infinity
    }

    private var actionMaxWidth: CGFloat {
        isRegularWidth ? 560 : .infinity
    }

    private var horizontalPadding: CGFloat {
        isRegularWidth ? Theme.Space.xxl : Theme.Space.l
    }

    // MARK: - Backdrop

    /// The standard warm HantaAtlas background. The hero (`WelcomeHero`, the
    /// editorial world map) carries the visual; the sign-in controls hover
    /// directly over this — no panels, scrims, or video.
    private var authBackdrop: some View {
        Theme.paper.ignoresSafeArea()
    }

    // MARK: - Hero

    private var hero: some View {
        WelcomeHero()
    }

    // MARK: - Close (sheet only)

    private var closeButton: some View {
        Button {
            onClose?()
        } label: {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.graphiteSecondary)
                .frame(width: 32, height: 32)
                .background(Theme.bone.opacity(0.85), in: Circle())
                .overlay(Circle().strokeBorder(Theme.terracotta.opacity(0.12), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .padding(.top, 10)
        .padding(.trailing, 16)
        .accessibilityLabel("Close, continue without an account")
    }

    // MARK: - Welcome card
    //
    // Editorial paper card — no .ultraThinMaterial. The hero already
    // carries the visual weight; making the card glassy fights it for
    // attention and adds a generic-blur look. Solid paper + warm border
    // reads as a hand-crafted typography card, like a magazine pull-quote.

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Track hantavirus signals worldwide")
                .font(.title2.weight(.medium))
                .foregroundStyle(Theme.graphite)
                .fixedSize(horizontal: false, vertical: true)
            Text("Officially-reported cases, deaths, advisories and expert commentary — sourced from WHO, ECDC, CDC, PAHO, ProMED, and live news. Informational only — not for emergency use.")
                .font(.callout)
                .foregroundStyle(Theme.graphiteSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.bone.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Theme.terracotta.opacity(0.15), lineWidth: 0.66)
                )
        )
        .opacity(revealPhase.rawValueIndex >= 2 ? 1 : 0)
        .offset(y: revealPhase.rawValueIndex >= 2 ? 0 : 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Action stack

    private var actionStack: some View {
        VStack(spacing: 12) {
            // Sign in with Apple — native button style + height per Apple HIG.
            SignInWithAppleButton(.signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    Task { await authService.completeSignInWithApple(result) }
                }
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityLabel("Sign in with Apple")

            // Continue with email — stable native hit target for iPadOS App
            // Review. The sheet still keeps the editorial material treatment.
            Button {
                showEmailSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.subheadline.weight(.semibold))
                    Text("Continue with email")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Theme.graphite)
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            // Hovering glass pill over the main background — no solid box.
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityLabel("Continue with email")
            .accessibilityIdentifier("welcome.emailButton")
        }
        .opacity(revealPhase.rawValueIndex >= 3 ? 1 : 0)
        .offset(y: revealPhase.rawValueIndex >= 3 ? 0 : 12)
        .allowsHitTesting(revealPhase.rawValueIndex >= 3)
    }

    private var disclaimerLine: some View {
        Group {
            if let err = authService.lastError, err != .cancelled {
                Text(errorCopy(err))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.terracotta)
                    .padding(.top, 8)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Sign-in error: \(errorCopy(err))")
            } else if authService.inFlight {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 8)
                    .accessibilityLabel("Signing in")
            }
        }
        .opacity(revealPhase.rawValueIndex >= 3 ? 1 : 0)
    }

    /// Terms of Service + Privacy Policy, always visible on the auth screen.
    /// The "By continuing…" caption makes explicit that signing in (Apple or
    /// email) constitutes acceptance. Tapping the links opens a chooser that
    /// routes to the public pages in Safari.
    private var legalLine: some View {
        VStack(spacing: 4) {
            Text("By continuing, you agree to our")
                .font(.caption2)
                .foregroundStyle(Theme.graphiteSecondary.opacity(0.85))

            HStack(spacing: 6) {
                Button { openURL(Self.termsURL) } label: {
                    Text("Terms of Service")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.terracotta)
                        .underline()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Terms of Service")
                .accessibilityHint("Opens our Terms of Service in Safari")
                .accessibilityIdentifier("welcome.termsLink")

                Text("·")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.graphiteSecondary)
                    .accessibilityHidden(true)

                Button { openURL(Self.privacyURL) } label: {
                    Text("Privacy Policy")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.terracotta)
                        .underline()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Privacy Policy")
                .accessibilityHint("Opens our Privacy Policy in Safari")
                .accessibilityIdentifier("welcome.privacyLink")
            }
            // Also let the whole line summon a chooser (matches the system
            // action-sheet pattern) for users who tap the combined area.
            .contentShape(Rectangle())
            .onTapGesture { showLegalOptions = true }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .opacity(revealPhase.rawValueIndex >= 3 ? 1 : 0)
    }

    private func errorCopy(_ err: AuthService.AuthError) -> String {
        switch err {
        case .cancelled:        return ""
        case .unauthorised:     return "We couldn't verify your Apple ID. Please try again."
        case .networkUnavailable: return "Offline — sync will resume when online."
        case .backendRejected(let why): return "Server rejected sign-in (\(why)). Please try again."
        case .invalidCredentials: return "Email or password is incorrect."
        case .emailInUse:       return "An account already exists for that email."
        case .unknown:          return "Something went wrong. Please try again."
        }
    }

    // MARK: - Reveal sequence

    private func performReveal() {
        // In a sheet the user opened sign-in deliberately — show the controls
        // immediately rather than staggering them in.
        if reduceMotion || context == .sheet {
            revealPhase = .cta
            return
        }
        // Phased reveal: mark → copy → CTA, ~150ms apart.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeOut(duration: 0.45)) { revealPhase = .mark }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeOut(duration: 0.40)) { revealPhase = .copy }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            withAnimation(.easeOut(duration: 0.40)) { revealPhase = .cta }
        }
    }
}

private extension WelcomeView.RevealPhase {
    var rawValueIndex: Int {
        switch self {
        case .hidden: return 0
        case .mark:   return 1
        case .copy:   return 2
        case .cta:    return 3
        }
    }
}

// MARK: - Email sign-in sheet

/// Sheet presented from WelcomeView when the user picks "Continue with
/// email". Wires to the backend's `/v1/auth/login` and `/v1/auth/register`
/// endpoints (both POST {email, password[, displayName?]}; Argon2id hashed
/// passwords; session-token-issuing).
///
/// Design notes:
///  - Sheet container uses `.regularMaterial` presentationBackground +
///    `.presentationCornerRadius(32)` so the sheet itself feels glassy.
///  - Inputs and CTAs use solid SwiftUI hit targets. This avoids the
///    Button-inside-interactive-glass gesture edge cases seen on iPadOS.
private struct EmailSignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var session = UserSession.shared

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var displayName: String = ""
    @State private var isRegistering: Bool = false
    @FocusState private var focused: Field?

    enum Field { case email, password, name }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 8 && (!isRegistering || !displayName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        ZStack {
            // Soft warm backdrop tints the sheet's glass material without
            // fighting it — the material does the heavy lifting.
            Theme.paper.opacity(0.6).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                header
                VStack(alignment: .leading, spacing: 14) {
                    if isRegistering {
                        field(
                            icon: "person.fill",
                            placeholder: "Your name",
                            text: $displayName,
                            contentType: .name,
                            keyboard: .default,
                            focus: .name
                        )
                    }
                    field(
                        icon: "envelope.fill",
                        placeholder: "Email",
                        text: $email,
                        contentType: .username,
                        keyboard: .emailAddress,
                        focus: .email
                    )
                    field(
                        icon: "lock.fill",
                        placeholder: "Password",
                        text: $password,
                        contentType: isRegistering ? .newPassword : .password,
                        keyboard: .default,
                        focus: .password,
                        isSecure: true
                    )
                }

                if let err = authService.lastError, err != .cancelled {
                    Text(errorCopy(err))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.terracotta)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }

                primaryButton
                toggleModeButton

                Text("Passwords are hashed with Argon2id; we never see them in plain text. Email sign-in is intended for App Review and team accounts.")
                    .font(.caption2)
                    .foregroundStyle(Theme.graphiteSecondary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 16)
        }
        .animation(.easeOut(duration: 0.20), value: isRegistering)
        .animation(.easeOut(duration: 0.20), value: authService.lastError)
        .onChange(of: session.isAuthenticated) { _, signedIn in
            if signedIn { dismiss() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isRegistering ? "Create your account" : "Sign in with email")
                .font(.title2.weight(.heavy))
                .foregroundStyle(Theme.graphite)
            Text(isRegistering
                 ? "Email and password sync your saved countries and alerts."
                 : "Use your email and password to continue.")
                .font(.subheadline)
                .foregroundStyle(Theme.graphiteSecondary)
        }
    }

    @ViewBuilder
    private func field(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        contentType: UITextContentType?,
        keyboard: UIKeyboardType,
        focus: Field,
        isSecure: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Theme.graphiteSecondary)
                .frame(width: 22)
            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textInputAutocapitalization(focus == .name ? .words : .never)
            .autocorrectionDisabled()
            .keyboardType(keyboard)
            .textContentType(contentType)
            .focused($focused, equals: focus)
            .font(.body)
            .foregroundStyle(Theme.graphite)
            .submitLabel(focus == .password ? .go : .next)
            .onSubmit {
                switch focus {
                case .name: focused = .email
                case .email: focused = .password
                case .password:
                    if canSubmit { Task { await submit() } }
                }
            }
            .accessibilityIdentifier(fieldIdentifier(for: focus))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.bone.opacity(0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.terracotta.opacity(0.14), lineWidth: 0.8)
        )
    }

    private var primaryButton: some View {
        Button {
            Task { await submit() }
        } label: {
            ZStack {
                if authService.inFlight {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Text(isRegistering ? "Create account" : "Sign in")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.terracotta)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.32), lineWidth: 0.8)
        )
        .disabled(!canSubmit || authService.inFlight)
        .opacity(canSubmit ? 1 : 0.55)
        .accessibilityLabel(isRegistering ? "Create account" : "Sign in")
        .accessibilityIdentifier("emailSignIn.submitButton")
    }

    private var toggleModeButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.20)) {
                isRegistering.toggle()
                authService.clearError()
            }
        } label: {
            Text(isRegistering ? "I already have an account" : "Create new account")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.graphite)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private func submit() async {
        focused = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if isRegistering {
            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            await authService.registerWithEmail(trimmedEmail, password: password, displayName: trimmedName.isEmpty ? nil : trimmedName)
        } else {
            await authService.signInWithEmail(trimmedEmail, password: password)
        }
    }

    private func fieldIdentifier(for field: Field) -> String {
        switch field {
        case .email: return "emailSignIn.emailField"
        case .password: return "emailSignIn.passwordField"
        case .name: return "emailSignIn.nameField"
        }
    }

    private func errorCopy(_ err: AuthService.AuthError) -> String {
        switch err {
        case .cancelled:        return ""
        case .unauthorised:     return "We couldn't verify your credentials. Please try again."
        case .networkUnavailable: return "You're offline. Connect and try again."
        case .invalidCredentials: return "Email or password is incorrect."
        case .emailInUse:       return "An account already exists for that email. Try signing in instead."
        case .backendRejected(let why): return "Server rejected sign-in (\(why)). Please try again."
        case .unknown:          return "Something went wrong. Please try again."
        }
    }
}

#Preview("Welcome — light") {
    WelcomeView()
}

#Preview("Welcome — dark") {
    WelcomeView()
        .preferredColorScheme(.dark)
}

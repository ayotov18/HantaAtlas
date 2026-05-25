import Foundation
import Observation

/// Coordinates *contextual* sign-in. The app is fully browsable without an
/// account; whenever the user invokes a profile action (save a country, open
/// Profile, change alert settings) the call site funnels through `require`.
/// If already signed in, the action runs immediately. Otherwise the sign-in
/// sheet is presented and the action is deferred until sign-in succeeds.
///
/// This is the App Review-safe pattern (Guideline 5.1.1(v)): non-account
/// features stay reachable; we only ask for an account at the moment one is
/// actually needed.
///
/// The sheet itself is presented once, at the app root (`ContentView`), bound
/// to `isPresentingSignIn`. `ContentView` observes `UserSession.isAuthenticated`
/// and calls `fulfilPendingIfAuthenticated()` when it flips true.
@MainActor
@Observable
final class AuthGate {
    static let shared = AuthGate()

    /// Drives the root sign-in sheet.
    var isPresentingSignIn = false

    /// The action to run once the user finishes signing in. Not observed —
    /// it's control flow, not view state.
    @ObservationIgnored private var pendingAction: (() -> Void)?

    private let session: UserSession

    init(session: UserSession = .shared) {
        self.session = session
    }

    /// Runs `action` now if the user is signed in; otherwise stashes it and
    /// presents the sign-in sheet. The action runs after a successful sign-in,
    /// or is dropped if the user cancels.
    func require(_ action: @escaping () -> Void) {
        if session.isAuthenticated {
            action()
        } else {
            pendingAction = action
            isPresentingSignIn = true
        }
    }

    /// Called by the root when `UserSession.isAuthenticated` becomes true while
    /// the sheet is up: dismiss and run whatever the user was trying to do.
    func fulfilPendingIfAuthenticated() {
        guard session.isAuthenticated else { return }
        let action = pendingAction
        pendingAction = nil
        isPresentingSignIn = false
        guard let action else { return }
        // Defer to the next runloop so the sign-in sheet finishes dismissing
        // before an action that itself presents UI (e.g. opening Profile) runs
        // — avoids the "present while dismissing" sheet race.
        Task { @MainActor in action() }
    }

    /// User dismissed the sheet without signing in — drop the pending action.
    func cancel() {
        pendingAction = nil
        isPresentingSignIn = false
    }
}

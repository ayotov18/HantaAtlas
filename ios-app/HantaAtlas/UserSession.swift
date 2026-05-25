import Foundation
import Observation

/// Source of truth for the user's authentication state. `@Observable` so any
/// SwiftUI surface can reactively show "signed in as X" / sign-in gate
/// without wiring its own bindings. Persists session token + identity hints
/// to the Keychain (KeychainStore). Sign in with Apple is mandatory — the
/// root app gate (HantaAtlasApp.hostContent) keeps the user on WelcomeView
/// until `isAuthenticated` is true.
///
/// This deliberately only tracks *identity*.
@MainActor
@Observable
final class UserSession {
    static let shared = UserSession()

    /// The signed-in user's profile, or `nil` when signed out.
    private(set) var currentUser: AuthenticatedUser? = nil
    /// Whether the user has an active server-issued session token.
    var isAuthenticated: Bool { currentUser != nil }

    /// Set true once `rehydrate()` has started. The root app gate uses this
    /// to avoid blocking the whole UI on Keychain. A cached session can still
    /// arrive a moment later and swap WelcomeView -> ContentView reactively.
    private(set) var hasRehydrated: Bool = false

    /// Bumps whenever an explicit auth action changes local session state.
    /// Rehydrate captures this value before its background Keychain read and
    /// only applies the cached user if nothing newer has happened.
    private var sessionMutationSerial: Int = 0

    private init() {
        // Intentionally empty. The previous version called
        // `rehydrateFromKeychain()` here — four synchronous Keychain reads on
        // the main thread before the first frame. Apple's launch-time guidance
        // ("Initialize nonview functionality, such as persistent storage and
        // location services, on first use rather than on app launch" —
        // developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time)
        // says to defer this. The app entry point now invokes `rehydrate()`
        // from a `.task(priority: .userInitiated)`, off the critical path.
    }

    /// Pull cached identity from Keychain. Idempotent — safe to call more than
    /// once. Off-init so it never blocks first-frame render.
    func rehydrate() async {
        guard !hasRehydrated else { return }
        hasRehydrated = true
        let mutationSerialAtStart = sessionMutationSerial

        // Move Keychain access off the main thread. Security framework calls
        // can block tens or hundreds of ms on first access. The auth gate is
        // already released above, so a slow Keychain cannot leave launch stuck
        // on the intermediate paper/auth state.
        let snapshot: AuthenticatedUser? = await Task.detached(priority: .userInitiated) {
            guard
                let token = KeychainStore.get(.sessionToken),
                !token.isEmpty
            else { return nil }
            return AuthenticatedUser(
                sessionToken: token,
                email: KeychainStore.get(.email),
                displayName: KeychainStore.get(.displayName),
                appleSubject: KeychainStore.get(.appleSubject)
            )
        }.value
        guard sessionMutationSerial == mutationSerialAtStart else { return }

        currentUser = snapshot
        // Recovery path for users whose local copy is missing displayName /
        // email — fetch from /v1/auth/me. The backend holds whatever Apple
        // delivered on the user's first sign-in, even if the client lost it.
        // Without this, users who hit the previous welcome-flow bug (which
        // discarded the first-sign-in credential) would be stuck seeing
        // "Signed in / No account on this device" forever.
        if let user = currentUser, (user.displayName == nil || user.email == nil) {
            await refreshProfileFromBackend()
        }
    }

    /// Hit `GET /v1/auth/me` with the cached bearer token and merge any
    /// displayName / email the server has back into local state + Keychain.
    /// Silent failure on network or auth error — the user stays signed in
    /// with whatever local data we have; we just won't enrich it this run.
    func refreshProfileFromBackend() async {
        guard let user = currentUser else { return }
        // Sentinel tokens (no backend round-trip yet) can't be exchanged.
        guard !user.sessionToken.hasPrefix("apple:") else { return }
        let mutationSerialAtStart = sessionMutationSerial

        let url = URL(string: APIClient.resolvedBaseURL.absoluteString + "/v1/auth/me")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(user.sessionToken)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 5

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let decoded = try JSONDecoder().decode(MeResponse.self, from: data)
            var updated = user
            if let serverName = decoded.user.displayName, !serverName.isEmpty {
                updated.displayName = serverName
                KeychainStore.set(serverName, for: .displayName)
            }
            if let serverEmail = decoded.user.email, !serverEmail.isEmpty {
                updated.email = serverEmail
                KeychainStore.set(serverEmail, for: .email)
            }
            guard
                sessionMutationSerial == mutationSerialAtStart,
                currentUser?.sessionToken == user.sessionToken
            else { return }
            currentUser = updated
        } catch {
            // No-op — we keep whatever local state we already have.
        }
    }

    func signedIn(user: AuthenticatedUser) {
        sessionMutationSerial += 1
        hasRehydrated = true
        currentUser = user
        KeychainStore.set(user.sessionToken, for: .sessionToken)
        KeychainStore.set(user.email, for: .email)
        KeychainStore.set(user.displayName, for: .displayName)
        KeychainStore.set(user.appleSubject, for: .appleSubject)
    }

    func signOut() {
        sessionMutationSerial += 1
        hasRehydrated = true
        currentUser = nil
        KeychainStore.clearAll()
    }

    /// Permanently delete the account (App Review 5.1.1(v) requires this in-app).
    /// Calls `DELETE /v1/auth/account` (soft-deletes the user + revokes sessions
    /// server-side), then tears down local state via `signOut()`. Returns `false`
    /// on a network/server failure so the UI can ask the user to retry — we must
    /// not pretend to delete while offline.
    func deleteAccount() async -> Bool {
        guard let user = currentUser else { signOut(); return true }
        // Local-only sentinel sessions never reached the backend, so there's no
        // server-side account to delete — just clear local state.
        if user.sessionToken.hasPrefix("apple:") {
            signOut()
            return true
        }

        var req = URLRequest(url: URL(string: APIClient.resolvedBaseURL.absoluteString + "/v1/auth/account")!)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(user.sessionToken)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 8

        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { return false }
            // 204 = deleted; 401 = token already invalid (account effectively gone).
            guard http.statusCode == 204 || http.statusCode == 401 else { return false }
            signOut()
            return true
        } catch {
            return false
        }
    }
}

/// Sendable value type representing the signed-in user. Held by `UserSession`,
/// passed into views.
struct AuthenticatedUser: Codable, Sendable, Equatable {
    let sessionToken: String
    var email: String?
    var displayName: String?
    var appleSubject: String?

    /// Best-effort initials for avatar rendering.
    var initials: String {
        let source = displayName ?? email ?? ""
        let parts = source.split(whereSeparator: { $0 == " " || $0 == "@" || $0 == "." })
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        let combined = (first + second).uppercased()
        return combined.isEmpty ? "👤" : combined
    }

    var displayNameOrFallback: String {
        if let n = displayName, !n.isEmpty { return n }
        if let e = email, !e.isEmpty { return e }
        return "Signed in"
    }
}

// MARK: - /v1/auth/me wire format

/// Mirrors the response shape from `GET /v1/auth/me` on the backend
/// (`auth-routes.ts` → `publicUser(user)` + `entitlements`). Kept tight —
/// we only decode the fields we'll surface in the profile screen.
private struct MeResponse: Decodable {
    let user: MeUser
    struct MeUser: Decodable {
        let id: String
        let email: String?
        let displayName: String?
    }
}

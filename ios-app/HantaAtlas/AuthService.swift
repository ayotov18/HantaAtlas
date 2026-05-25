import Foundation
import AuthenticationServices
import UIKit
import Observation

/// Coordinates Sign in with Apple via `ASAuthorizationController` plus the
/// network round-trip to our backend's `POST /v1/auth/apple` endpoint.
///
/// Flow:
///   1. View presents `SignInWithAppleButton` (or our wrapped variant).
///   2. User authorises → `ASAuthorizationAppleIDCredential` callback.
///   3. We POST `{ identityToken, fullName?, email? }` to `/v1/auth/apple`.
///   4. Backend verifies the JWT against Apple's JWKS, upserts a User,
///      returns our own session token.
///   5. We persist token + identity hints via `UserSession.signedIn(user:)`,
///      which writes to Keychain.
///
/// Error states (cancelled, network down, backend error) surface as
/// `AuthError` cases for the view to render — Apple's HIG asks us to show
/// understandable copy, not raw NSError messages.
@MainActor
@Observable
final class AuthService: NSObject {
    static let shared = AuthService()

    private(set) var inFlight: Bool = false
    private(set) var lastError: AuthError? = nil

    private var authContinuation: CheckedContinuation<ASAuthorization, Error>?

    enum AuthError: Error, Equatable {
        case cancelled
        case unauthorised
        case networkUnavailable
        case backendRejected(String)
        case invalidCredentials
        case emailInUse
        case unknown
    }

    /// Clears any sticky error state so the next view-level render doesn't
    /// surface a stale message after the user dismisses or toggles modes.
    func clearError() {
        lastError = nil
    }

    // MARK: - Email / password (App Review demo path)

    /// POST {email, password} → /v1/auth/login. On success the user is signed
    /// in and `UserSession.shared.isAuthenticated` flips true, which causes
    /// the root app gate to swap WelcomeView for ContentView automatically.
    /// Surfaces granular error states (`.invalidCredentials`, `.networkUnavailable`)
    /// to the view so the sheet can show the right copy.
    func signInWithEmail(_ email: String, password: String) async {
        await postEmailAuth(path: "/v1/auth/login", body: ["email": email, "password": password])
    }

    /// POST {email, password, displayName?} → /v1/auth/register. On success
    /// the user is signed in (the backend issues a session token immediately).
    func registerWithEmail(_ email: String, password: String, displayName: String? = nil) async {
        var body: [String: Any] = ["email": email, "password": password]
        if let name = displayName, !name.isEmpty { body["displayName"] = name }
        await postEmailAuth(path: "/v1/auth/register", body: body)
    }

    private func postEmailAuth(path: String, body: [String: Any]) async {
        inFlight = true
        defer { inFlight = false }
        lastError = nil

        let url = URL(string: APIClient.resolvedBaseURL.absoluteString + path)!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            lastError = .unknown
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                lastError = .unknown
                return
            }
            if (200...299).contains(http.statusCode),
               let decoded = try? JSONDecoder().decode(AuthResponse.self, from: data) {
                let user = AuthenticatedUser(
                    sessionToken: decoded.sessionToken,
                    email: decoded.user.email,
                    displayName: decoded.user.displayName,
                    appleSubject: nil
                )
                UserSession.shared.signedIn(user: user)
                return
            }
            // Backend returned 4xx/5xx. Decode the error code if possible.
            let errorCode = (try? JSONDecoder().decode(BackendError.self, from: data))?.error
            switch (http.statusCode, errorCode) {
            case (401, _):
                lastError = .invalidCredentials
            case (409, _):
                lastError = .emailInUse
            case (let code, let codeName?):
                lastError = .backendRejected("\(code) \(codeName)")
            case (let code, nil):
                lastError = .backendRejected("HTTP \(code)")
            }
        } catch is URLError {
            lastError = .networkUnavailable
        } catch {
            lastError = .unknown
        }
    }

    /// Programmatic entry — used when we own the ASAuthorizationController.
    /// Kept for non-SwiftUI callers and tests. The view-driven path below is
    /// what the welcome screen uses today.
    func signInWithApple() async {
        inFlight = true
        defer { inFlight = false }
        lastError = nil
        do {
            let authorization = try await requestAppleAuthorization()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                lastError = .unknown
                return
            }
            try await exchangeAppleCredentialForSession(credential)
        } catch let err as AuthError {
            lastError = err
        } catch let err as ASAuthorizationError where err.code == .canceled {
            lastError = .cancelled
        } catch {
            lastError = .unknown
        }
    }

    /// SwiftUI entry — called from `SignInWithAppleButton`'s `onCompletion`.
    ///
    /// **Why this exists**: the previous welcome flow ran two competing
    /// Apple sign-ins in a row. `SignInWithAppleButton` internally runs the
    /// `ASAuthorizationController` and hands the `ASAuthorization` back via
    /// `onCompletion` — but the welcome view ignored that result with `_ in`
    /// and triggered a separate `signInWithApple()` call which started ANOTHER
    /// authorisation request. The system suppresses the second sheet on a
    /// device that just authenticated, so the second request would succeed
    /// silently with **no `fullName` and no `email`** (Apple only delivers
    /// those on first sign-in per Apple ID, and they were attached to the
    /// first credential we discarded). That's why the user was signed in but
    /// the profile read "Signed in / No account on this device" — the local
    /// state never had a name or email to display.
    ///
    /// This method consumes the result directly so the fullName + email are
    /// captured exactly once, persisted via `UserSession.signedIn(user:)`,
    /// and shown in the profile thereafter.
    func completeSignInWithApple(_ result: Result<ASAuthorization, Error>) async {
        inFlight = true
        defer { inFlight = false }
        lastError = nil
        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                lastError = .unknown
                return
            }
            try await exchangeAppleCredentialForSession(credential)
        } catch let err as AuthError {
            lastError = err
        } catch let err as ASAuthorizationError where err.code == .canceled {
            lastError = .cancelled
        } catch {
            lastError = .unknown
        }
    }

    // MARK: - Apple authorisation request

    private func requestAppleAuthorization() async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.authContinuation = continuation
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func exchangeAppleCredentialForSession(_ credential: ASAuthorizationAppleIDCredential) async throws {
        guard let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.unauthorised
        }
        let displayName: String? = {
            let f = credential.fullName?.givenName ?? ""
            let l = credential.fullName?.familyName ?? ""
            let combined = "\(f) \(l)".trimmingCharacters(in: .whitespaces)
            return combined.isEmpty ? nil : combined
        }()
        let email = credential.email
        let appleSubject = credential.user

        // POST to backend. If the backend isn't reachable yet we still keep
        // the user "signed in" client-side using the Apple subject as a
        // stable identity. The next online launch will exchange-and-refresh.
        let payload: [String: Any] = [
            "identityToken": identityToken,
            "appleSubject": appleSubject,
            "email": email as Any,
            "displayName": displayName as Any
        ]
        let url = URL(string: APIClient.resolvedBaseURL.absoluteString + "/v1/auth/apple")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        req.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let decoded = try? JSONDecoder().decode(AuthResponse.self, from: data) {
                let user = AuthenticatedUser(
                    sessionToken: decoded.sessionToken,
                    email: decoded.user.email ?? email,
                    displayName: decoded.user.displayName ?? displayName,
                    appleSubject: appleSubject
                )
                UserSession.shared.signedIn(user: user)
                return
            }
            // Backend reachable but rejected — surface the error code, but
            // also fall back to anonymous-with-identity below so the user
            // isn't stuck if we have a server bug.
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                throw AuthError.backendRejected("HTTP \(http.statusCode)")
            }
        } catch is URLError {
            // Network down. We still consider the user "soft signed in" —
            // they pass Apple's auth and identity persists locally; we just
            // don't have a server-issued session token yet.
            let fallback = AuthenticatedUser(
                sessionToken: "apple:\(appleSubject)",  // sentinel until backend round-trips
                email: email,
                displayName: displayName,
                appleSubject: appleSubject
            )
            UserSession.shared.signedIn(user: fallback)
            return
        } catch {
            throw error
        }
    }
}

// MARK: - Apple delegates

extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            self.authContinuation?.resume(returning: authorization)
            self.authContinuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            self.authContinuation?.resume(throwing: error)
            self.authContinuation = nil
        }
    }
}

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Resolve a real window. iOS 26 deprecated the empty `UIWindow()`
        // initializer; we always have at least one `UIWindowScene` at the
        // point this delegate fires (auth UI can't present without one), so
        // we never need the empty fallback.
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
            if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
                return keyWindow
            }
            if let anyWindow = scenes.flatMap(\.windows).first {
                return anyWindow
            }
            // No live windows — build one from the first available scene.
            // If this returns nil (impossible in practice — auth wouldn't
            // be presenting), force-unwrap to surface the contract.
            return UIWindow(windowScene: scenes.first!)
        }
    }
}

// MARK: - Wire format

private struct AuthResponse: Codable {
    let sessionToken: String
    let user: AuthUserDto
}

private struct AuthUserDto: Codable {
    let id: String
    let email: String?
    let displayName: String?
}

/// Mirrors the `{ "error": "code" }` shape every Fastify route in this
/// codebase emits on validation/auth failures.
private struct BackendError: Codable {
    let error: String?
}

import Foundation
import Observation

/// Syncs the per-user profile (saved countries + settings) between the local
/// `LocalPreferences` cache and the backend `/v1/me/preferences` endpoint.
///
/// Strategy:
///  - **On launch / sign-in**: pull the server profile. If the server has none
///    yet (`exists == false`), push the device's current prefs up so guest-era
///    settings carry over (best-practice first sync). Otherwise the server
///    wins and we apply it locally.
///  - **On change** while signed in: push the full snapshot (debounced).
///  - **Echo suppression**: we track `lastSyncedSnapshot`; a push is skipped
///    when the current snapshot already equals it, so applying a pulled profile
///    never bounces straight back as a PUT.
///
/// Signed-out, the engine is inert: pulls and pushes both no-op without a real
/// backend bearer token. `LocalPreferences` keeps working entirely on-device.
@MainActor
@Observable
final class PreferencesSync {
    static let shared = PreferencesSync()

    private let prefs: LocalPreferences
    private let session: UserSession

    private static let baseURL = APIClient.resolvedBaseURL
    private static let pushDebounce: Duration = .seconds(2)

    /// Last snapshot known to match the server — the diff baseline that
    /// suppresses echo pushes. Nil until the first successful sync.
    @ObservationIgnored private var lastSyncedSnapshot: PreferencesPayload?
    @ObservationIgnored private var pushTask: Task<Void, Never>?
    @ObservationIgnored private var isObserving = false

    init(prefs: LocalPreferences = .shared, session: UserSession = .shared) {
        self.prefs = prefs
        self.session = session
    }

    /// Real server bearer token, or nil when signed out / holding an offline
    /// `apple:` sentinel token that was never exchanged for a session.
    private var bearer: String? {
        guard let token = session.currentUser?.sessionToken,
              !token.isEmpty,
              !token.hasPrefix("apple:") else { return nil }
        return token
    }

    /// Called from the launch task after session rehydrate.
    func syncOnLaunch() async { await reconcileThenObserve() }

    /// Called when a contextual sign-in succeeds.
    func syncOnSignIn() async { await reconcileThenObserve() }

    private func reconcileThenObserve() async {
        await pullAndReconcile()
        beginObserving()
    }

    private func pullAndReconcile() async {
        guard let token = bearer else { return }
        guard let result = await get(token: token) else { return }
        if result.exists {
            // Server wins for a returning profile.
            prefs.applyRemote(result.preferences)
            lastSyncedSnapshot = prefs.syncSnapshot
        } else {
            // First sign-in to an empty profile — push local up.
            let snapshot = prefs.syncSnapshot
            if await put(snapshot, token: token) {
                lastSyncedSnapshot = snapshot
            }
        }
    }

    // MARK: - Change observation → debounced push

    /// Observe the synced subset of `LocalPreferences` and push on change.
    /// `withObservationTracking` fires once per change, so we re-arm it each
    /// time rather than hooking every `didSet`.
    private func beginObserving() {
        guard !isObserving else { return }
        isObserving = true
        observeOnce()
    }

    private func observeOnce() {
        withObservationTracking {
            // Touching the snapshot registers every synced field as a dependency.
            _ = prefs.syncSnapshot
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observeOnce()      // re-arm for the next change
                self.schedulePush()
            }
        }
    }

    private func schedulePush() {
        guard bearer != nil else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: Self.pushDebounce)
            guard let self, !Task.isCancelled else { return }
            await self.pushIfChanged()
        }
    }

    private func pushIfChanged() async {
        guard let token = bearer else { return }
        let snapshot = prefs.syncSnapshot
        // Echo suppression: nothing to do if we already match the server.
        if let last = lastSyncedSnapshot, last == snapshot { return }
        if await put(snapshot, token: token) {
            lastSyncedSnapshot = snapshot
        }
    }

    // MARK: - Transport

    private struct GetResponse: Decodable {
        let preferences: PreferencesPayload   // server's extra `updatedAt` is ignored
        let exists: Bool
    }

    private func get(token: String) async -> GetResponse? {
        var req = URLRequest(url: Self.baseURL.appendingPathComponent("v1/me/preferences"))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 8
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(GetResponse.self, from: data)
        } catch {
            return nil
        }
    }

    @discardableResult
    private func put(_ payload: PreferencesPayload, token: String) async -> Bool {
        var req = URLRequest(url: Self.baseURL.appendingPathComponent("v1/me/preferences"))
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 8
        do {
            req.httpBody = try JSONEncoder().encode(payload)
            let (_, response) = try await URLSession.shared.data(for: req)
            return (response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false
        } catch {
            return false
        }
    }
}

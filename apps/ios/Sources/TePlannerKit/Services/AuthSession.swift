import Foundation
import Combine

/// Single source of truth for "is the user logged in and bound to a Tesla
/// account". Wraps `SecureStorage` (tokens, user_id) and `SettingsStore`
/// (the `tesla_linked` flag). Views observe this to decide whether to
/// show the login flow or the home screen.
@MainActor
public final class AuthSession: ObservableObject {
    @Published public private(set) var isLoggedIn: Bool

    private let secureStorage: SecureStorage
    private let settings: SettingsStore
    private var unauthorizedObserver: NSObjectProtocol?

    public init(
        secureStorage: SecureStorage = KeychainStorage.shared,
        settings: SettingsStore = UserDefaultsSettingsStore.shared
    ) {
        self.secureStorage = secureStorage
        self.settings = settings
        self.isLoggedIn = Self.computeLoggedIn(secureStorage: secureStorage, settings: settings)

        unauthorizedObserver = NotificationCenter.default.addObserver(
            forName: APIService.unauthorizedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isLoggedIn else { return }
                Log.auth.notice("session token rejected (401) — forcing logout")
                self.logout()
            }
        }
    }

    nonisolated deinit {
        if let unauthorizedObserver {
            NotificationCenter.default.removeObserver(unauthorizedObserver)
        }
    }

    public var authToken: String? { secureStorage.authToken }
    public var refreshToken: String? { secureStorage.refreshToken }
    public var userId: String? { secureStorage.userId }

    public func login(token: String, refreshToken: String?, userId: String) {
        secureStorage.authToken = token
        secureStorage.refreshToken = refreshToken
        secureStorage.userId = userId
        settings.teslaLinked = true
        refreshState()
        Log.auth.notice("login persisted (user=\(userId, privacy: .public), refresh=\(refreshToken != nil, privacy: .public))")
    }

    public func updateAccessToken(_ token: String, refreshToken: String?) {
        secureStorage.authToken = token
        if let refreshToken {
            secureStorage.refreshToken = refreshToken
        }
        refreshState()
        Log.auth.debug("access token updated (refresh rotated=\(refreshToken != nil, privacy: .public))")
    }

    public func logout() {
        secureStorage.removeAll()
        settings.teslaLinked = false
        refreshState()
        Log.auth.notice("logout — credentials cleared")
    }

    /// Server-side unbind: revokes the Tesla token at the backend
    /// (forces a fresh OAuth on next login) and clears local creds.
    /// Returns the API outcome so the view can surface "解绑成功" /
    /// "解绑失败" feedback.
    public func unbindTesla(api: APIServiceProtocol) async -> Result<BaseResponse, APIError> {
        guard let uid = userId else {
            logout()
            return .success(BaseResponse(success: true, message: "no-op (no user)"))
        }
        Log.auth.notice("unbind Tesla — uid=\(uid, privacy: .public)")
        let result = await api.unbindTesla(userId: uid)
        // Whatever the server says, drop the local credentials so the
        // app forces an OAuth on next launch.
        logout()
        return result
    }

    /// Apple 5.1.1(v) — permanently delete the account on the backend
    /// and wipe local credentials. Tesla's own account at tesla.com
    /// is untouched (only the user can revoke that). On server
    /// success we always logout locally; on server failure we surface
    /// the error but DO NOT logout — the user still has data on the
    /// server, so it's better to show "删除失败，请稍后再试" than to
    /// leave them in a half-deleted state.
    public func deleteAccount(api: APIServiceProtocol) async -> Result<BaseResponse, APIError> {
        Log.auth.warning("account deletion requested by user")
        let result = await api.deleteAccount()
        switch result {
        case .success:
            logout()
            Log.auth.warning("account deleted — local credentials cleared")
        case .failure(let err):
            Log.auth.error("account deletion failed: \(err.localizedDescription, privacy: .public)")
        }
        return result
    }

    private func refreshState() {
        isLoggedIn = Self.computeLoggedIn(secureStorage: secureStorage, settings: settings)
    }

    private static func computeLoggedIn(secureStorage: SecureStorage, settings: SettingsStore) -> Bool {
        guard settings.teslaLinked else { return false }
        guard let token = secureStorage.authToken, !token.isEmpty else { return false }
        guard let userId = secureStorage.userId, !userId.isEmpty else { return false }
        return true
    }
}

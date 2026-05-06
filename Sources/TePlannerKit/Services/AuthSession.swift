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

    public init(
        secureStorage: SecureStorage = KeychainStorage.shared,
        settings: SettingsStore = UserDefaultsSettingsStore.shared
    ) {
        self.secureStorage = secureStorage
        self.settings = settings
        self.isLoggedIn = Self.computeLoggedIn(secureStorage: secureStorage, settings: settings)
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
    }

    public func updateAccessToken(_ token: String, refreshToken: String?) {
        secureStorage.authToken = token
        if let refreshToken {
            secureStorage.refreshToken = refreshToken
        }
        refreshState()
    }

    public func logout() {
        secureStorage.removeAll()
        settings.teslaLinked = false
        refreshState()
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

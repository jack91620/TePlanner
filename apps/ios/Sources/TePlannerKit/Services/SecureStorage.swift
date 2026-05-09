import Foundation
import Security

/// Storage for credentials that must survive app restarts and never appear
/// in backups (auth_token, refresh_token, user_id). Protocol-fronted so
/// tests inject an in-memory implementation.
public protocol SecureStorage: AnyObject {
    func string(forKey key: String) -> String?
    func setString(_ value: String?, forKey key: String)
    func removeAll()
}

public extension SecureStorage {
    var authToken: String? {
        get { string(forKey: SecureStorageKey.authToken) }
        set { setString(newValue, forKey: SecureStorageKey.authToken) }
    }

    var refreshToken: String? {
        get { string(forKey: SecureStorageKey.refreshToken) }
        set { setString(newValue, forKey: SecureStorageKey.refreshToken) }
    }

    var userId: String? {
        get { string(forKey: SecureStorageKey.userId) }
        set { setString(newValue, forKey: SecureStorageKey.userId) }
    }
}

public enum SecureStorageKey {
    public static let authToken = "auth_token"
    public static let refreshToken = "refresh_token"
    public static let userId = "user_id"
}

/// Keychain-backed implementation. Items are stored with
/// `kSecAttrAccessibleAfterFirstUnlock` so they're available to background
/// operations after the first device unlock.
public final class KeychainStorage: SecureStorage {
    public static let shared = KeychainStorage(service: "com.teplanner.ios")

    private let service: String

    public init(service: String) {
        self.service = service
    }

    public func string(forKey key: String) -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func setString(_ value: String?, forKey key: String) {
        let query = baseQuery(forKey: key)

        guard let value, let data = value.data(using: .utf8) else {
            SecItemDelete(query as CFDictionary)
            return
        }

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem.merge(attributes) { _, new in new }
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    public func removeAll() {
        for key in [SecureStorageKey.authToken, SecureStorageKey.refreshToken, SecureStorageKey.userId] {
            SecItemDelete(baseQuery(forKey: key) as CFDictionary)
        }
    }

    private func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}

/// In-memory implementation for tests and previews.
public final class InMemorySecureStorage: SecureStorage {
    private var values: [String: String] = [:]
    private let queue = DispatchQueue(label: "InMemorySecureStorage")

    public init() {}

    public func string(forKey key: String) -> String? {
        queue.sync { values[key] }
    }

    public func setString(_ value: String?, forKey key: String) {
        queue.sync {
            if let value {
                values[key] = value
            } else {
                values.removeValue(forKey: key)
            }
        }
    }

    public func removeAll() {
        queue.sync { values.removeAll() }
    }
}

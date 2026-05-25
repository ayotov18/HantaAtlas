import Foundation
import Security

/// Thin wrapper around `Security.framework` for storing the session token
/// and Apple credential subject identifier. Backed by `kSecClassGenericPassword`
/// with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — survives reboots
/// after the first unlock, never leaves the device, and is excluded from
/// iCloud Keychain backups.
enum KeychainStore {
    static let service = "com.hantaatlas.app"

    enum Item: String {
        case sessionToken      = "session.token"
        case appleSubject      = "apple.subject"
        case email             = "user.email"
        case displayName       = "user.displayName"
    }

    @discardableResult
    static func set(_ value: String?, for item: Item) -> Bool {
        guard let value = value, !value.isEmpty else { return delete(item) }
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  item.rawValue
        ]
        let attrs: [String: Any] = [
            kSecValueData as String:    data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        // Try to update existing first; if not found, add.
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    static func get(_ item: Item) -> String? {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  item.rawValue,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func delete(_ item: Item) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  item.rawValue
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    static func clearAll() {
        for item in [Item.sessionToken, .appleSubject, .email, .displayName] {
            _ = delete(item)
        }
    }
}

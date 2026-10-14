import Foundation
import Security

enum KeychainHelper {
    // Kept from the app's former name, Raptorr, so existing sign-ins survive the rename.
    private static let service = "com.kylemcclain.Raptorr"

    static func save(_ value: String, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
        ]
        _ = SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = Data(value.utf8)
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        debugLog(status: status, operation: "save", key: key)
    }

    static func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                debugLog(status: status, operation: "load", key: key)
            }
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecItemNotFound {
            debugLog(status: status, operation: "delete", key: key)
        }
    }

    private static func debugLog(status: OSStatus, operation: String, key: String) {
        #if DEBUG
        guard status != errSecSuccess else { return }
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
        print("[Keychain][\(operation)] key=\(key) status=\(status) \(message)")
        #endif
    }
}

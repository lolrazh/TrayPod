import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.traypod.spotify"

    @discardableResult
    static func save(key: String, data: Data) -> Bool {
        let query = baseQuery(key: key)
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data

        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func load(key: String) -> Data? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    static func delete(key: String) {
        SecItemDelete(baseQuery(key: key) as CFDictionary)
    }

    private static func baseQuery(key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}

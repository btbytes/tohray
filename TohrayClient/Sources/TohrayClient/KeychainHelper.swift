import Foundation
import Security

class KeychainHelper {
    private let service = "com.tohray.client"

    // MARK: - URL
    func saveURL(_ url: String) {
        save(key: "url", value: url)
    }

    func getURL() -> String? {
        return get(key: "url")
    }

    // MARK: - Username
    func saveUsername(_ username: String) {
        save(key: "username", value: username)
    }

    func getUsername() -> String? {
        return get(key: "username")
    }

    // MARK: - Password
    func savePassword(_ password: String) {
        save(key: "password", value: password)
    }

    func getPassword() -> String? {
        return get(key: "password")
    }

    // MARK: - Generic Save/Get
    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete any existing item
        delete(key: key)

        // Add new item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

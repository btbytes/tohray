import Foundation
import Security

/// All settings persisted in the login keychain. Stored as a single JSON blob
/// under one keychain item so macOS only has to ask for access once, instead of
/// once per individual setting.
struct StoredSettings: Codable, Equatable {
    var url = "http://localhost:8080"
    var username = ""
    var password = ""

    var s3Provider = "Cloudflare"
    var s3AccessKeyID = ""
    var s3SecretAccessKey = ""
    var s3SessionToken = ""
    var s3Endpoint = ""
    var s3ACL = "private"
    var s3PublicURL = ""
    var s3RootDir = "/appname/"
    var s3Bucket = ""

    static let empty = StoredSettings()
}

class KeychainHelper {
    private let service = "dev.fly.tohray"
    private let account = "settings"

    /// Reads the consolidated settings blob. Never throws; empty settings are
    /// returned if nothing is stored yet.
    func load() -> StoredSettings {
        var settings = StoredSettings.empty
        loadData { data in
            if let data {
                settings = (try? JSONDecoder().decode(StoredSettings.self, from: data)) ?? StoredSettings.empty
            }
        }
        return settings
    }

    /// Writes the consolidated settings blob as a single keychain item.
    func save(_ settings: StoredSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        upsert(data: data)
    }

    // MARK: - Keychain primitives

    private func loadData(_ completion: (Data?) -> Void) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            completion(nil)
            return
        }
        guard status == errSecSuccess,
              let data = result as? Data else {
            completion(nil)
            return
        }
        completion(data)
    }

    private func upsert(data: Data) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        // Try updating first; if the item doesn't exist, add it.
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(query as CFDictionary, nil)
        }
    }
}

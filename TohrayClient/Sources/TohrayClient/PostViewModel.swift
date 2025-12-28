import Foundation
import SwiftUI

@MainActor
class PostViewModel: ObservableObject {
    @Published var content: String = ""
    @Published var slug: String = ""
    @Published var statusMessage: String = ""
    @Published var isError: Bool = false
    @Published var isPosting: Bool = false

    private let client = TohrayAPIClient()

    func post() async {
        isPosting = true
        statusMessage = "Posting..."
        isError = false

        do {
            let finalSlug = slug.isEmpty ? String(Int(Date().timeIntervalSince1970)) : slug
            let postURL = try await client.createPost(content: content, slug: finalSlug)

            statusMessage = "✓ Posted successfully! URL: \(postURL)"
            isError = false

            // Clear form after successful post
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.clear()
            }
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
            isError = true
        }

        isPosting = false
    }

    func clear() {
        content = ""
        slug = ""
        statusMessage = ""
        isError = false
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var url: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var statusMessage: String = ""
    @Published var isError: Bool = false

    private let keychain = KeychainHelper()

    init() {
        loadFromKeychain()
    }

    func loadFromKeychain() {
        url = keychain.getURL() ?? "http://localhost:8080"
        username = keychain.getUsername() ?? ""
        password = keychain.getPassword() ?? ""
    }

    func save() {
        keychain.saveURL(url)
        keychain.saveUsername(username)
        keychain.savePassword(password)
        statusMessage = "Settings saved to Keychain"
        isError = false
    }

    func testConnection() async {
        statusMessage = "Testing connection..."
        isError = false

        let client = TohrayAPIClient()
        do {
            try await client.testConnection(url: url, username: username, password: password)
            statusMessage = "✓ Connection successful!"
            isError = false
        } catch {
            statusMessage = "✗ Connection failed: \(error.localizedDescription)"
            isError = true
        }
    }
}

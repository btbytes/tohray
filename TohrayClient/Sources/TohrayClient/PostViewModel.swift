import AppKit
import Foundation
import SwiftUI

@MainActor
class PostViewModel: ObservableObject {
    @Published var content: String = ""
    @Published var slug: String = ""
    @Published var statusMessage: String = ""
    @Published var isError: Bool = false
    @Published var isPosting: Bool = false
    @Published var postedURL: URL?
    @Published var editingSlug: String?
    @Published var posts: [TohrayPost] = []
    @Published var isLoadingPosts: Bool = false

    private let client = TohrayAPIClient()

    var isEditing: Bool { editingSlug != nil }

    func post() async {
        isPosting = true
        statusMessage = "Posting..."
        isError = false
        postedURL = nil

        do {
            let finalSlug = slug.isEmpty ? String(Int(Date().timeIntervalSince1970)) : slug
            let postURL: String
            if isEditing {
                postURL = try await client.editPost(content: content, slug: finalSlug)
            } else {
                postURL = try await client.createPost(content: content, slug: finalSlug)
            }

            statusMessage = "✓ Saved successfully!"
            postedURL = URL(string: postURL)
            isError = false

            content = ""
            slug = ""
            editingSlug = nil
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
            isError = true
        }

        isPosting = false
    }

    func loadPosts() async {
        isLoadingPosts = true
        defer { isLoadingPosts = false }

        do {
            posts = try await client.fetchPosts()
                .sorted { $0.created > $1.created }
        } catch {
            statusMessage = "Error loading posts: \(error.localizedDescription)"
            isError = true
        }
    }

    func startEdit(_ post: TohrayPost) {
        slug = post.slug
        content = post.content
        editingSlug = post.slug
        statusMessage = ""
        isError = false
        postedURL = nil
    }

    func stopEditing() {
        editingSlug = nil
    }

    func copyURLToClipboard() {
        guard let postedURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(postedURL.absoluteString, forType: .string)
    }

    func clear() {
        content = ""
        slug = ""
        statusMessage = ""
        isError = false
        postedURL = nil
        editingSlug = nil
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

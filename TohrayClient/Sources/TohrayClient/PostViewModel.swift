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

    @Published var s3Provider = "Cloudflare"
    @Published var s3AccessKeyID = ""
    @Published var s3SecretAccessKey = ""
    @Published var s3SessionToken = ""
    @Published var s3Endpoint = ""
    @Published var s3ACL = "private"
    @Published var s3PublicURL = ""
    @Published var s3RootDir = "/appname/"
    @Published var s3Bucket = ""

    @Published var statusMessage: String = ""
    @Published var isError: Bool = false

    private let keychain = KeychainHelper()

    var s3Config: S3Config {
        var config = S3Config()
        config.provider = s3Provider
        config.accessKeyID = s3AccessKeyID
        config.secretAccessKey = s3SecretAccessKey
        config.sessionToken = s3SessionToken
        config.endpoint = s3Endpoint
        config.acl = s3ACL
        config.publicURL = s3PublicURL
        config.rootDir = s3RootDir
        config.bucket = s3Bucket
        return config
    }

    init() {
        loadFromKeychain()
    }

    func loadFromKeychain() {
        let stored = keychain.load()

        url = stored.url
        username = stored.username
        password = stored.password

        s3Provider = stored.s3Provider
        s3AccessKeyID = stored.s3AccessKeyID
        s3SecretAccessKey = stored.s3SecretAccessKey
        s3SessionToken = stored.s3SessionToken
        s3Endpoint = stored.s3Endpoint
        s3ACL = stored.s3ACL
        s3PublicURL = stored.s3PublicURL
        s3RootDir = stored.s3RootDir
        s3Bucket = stored.s3Bucket
    }

    func save() {
        var stored = StoredSettings()

        stored.url = url
        stored.username = username
        stored.password = password

        stored.s3Provider = s3Provider
        stored.s3AccessKeyID = s3AccessKeyID
        stored.s3SecretAccessKey = s3SecretAccessKey
        stored.s3SessionToken = s3SessionToken
        stored.s3Endpoint = s3Endpoint
        stored.s3ACL = s3ACL
        stored.s3PublicURL = s3PublicURL
        stored.s3RootDir = s3RootDir
        stored.s3Bucket = s3Bucket

        keychain.save(stored)
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

    func testS3Upload() async {
        statusMessage = "Testing S3 upload..."
        isError = false

        let uploader = S3Uploader()
        do {
            try await uploader.testConnection(config: s3Config)
            statusMessage = "✓ S3 upload successful!"
            isError = false
        } catch {
            statusMessage = "✗ S3 upload failed: \(error.localizedDescription)"
            isError = true
        }
    }
}

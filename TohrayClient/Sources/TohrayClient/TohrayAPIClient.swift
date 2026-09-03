import Foundation

enum TohrayError: LocalizedError {
    case invalidURL
    case invalidResponse
    case loginFailed(String)
    case postFailed(String)
    case noCredentials
    case csrfTokenNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .loginFailed(let message):
            return "Login failed: \(message)"
        case .postFailed(let message):
            return "Post failed: \(message)"
        case .noCredentials:
            return "No credentials found. Please configure in Settings."
        case .csrfTokenNotFound:
            return "Could not extract CSRF token from page"
        }
    }
}

struct TohrayPost: Codable, Identifiable {
    let slug: String
    let created: String
    let content: String

    var id: String { slug }
}

class TohrayAPIClient {
    private let keychain = KeychainHelper()
    private var cookies: [HTTPCookie] = []

    func testConnection(url: String, username: String, password: String) async throws {
        _ = try await login(baseURL: url, username: username, password: password)
    }

    func createPost(content: String, slug: String) async throws -> String {
        return try await submitPost(content: content, slug: slug, path: "/write")
    }

    func editPost(content: String, slug: String) async throws -> String {
        let path = "/edit/\(slug)"
        let settings = keychain.load()
        guard !settings.url.isEmpty else {
            throw TohrayError.noCredentials
        }
        _ = try await submitPost(content: content, slug: slug, path: path)
        return "\(settings.url)/\(slug)"
    }

    func fetchPosts() async throws -> [TohrayPost] {
        let settings = keychain.load()
        guard !settings.url.isEmpty,
              !settings.username.isEmpty,
              !settings.password.isEmpty else {
            throw TohrayError.noCredentials
        }

        _ = try await login(baseURL: settings.url, username: settings.username, password: settings.password)

        guard let url = URL(string: "\(settings.url)/export") else {
            throw TohrayError.invalidURL
        }

        var request = URLRequest(url: url)
        addCookies(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TohrayError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw TohrayError.postFailed("HTTP \(httpResponse.statusCode)")
        }

        struct ExportResponse: Codable {
            let posts: [TohrayPost]
        }

        do {
            let decoded = try JSONDecoder().decode(ExportResponse.self, from: data)
            return decoded.posts
        } catch {
            throw TohrayError.invalidResponse
        }
    }

    private func submitPost(content: String, slug: String, path: String) async throws -> String {
        let settings = keychain.load()
        guard !settings.url.isEmpty,
              !settings.username.isEmpty,
              !settings.password.isEmpty else {
            throw TohrayError.noCredentials
        }

        let baseURL = settings.url

        // Login first
        _ = try await login(baseURL: baseURL, username: settings.username, password: settings.password)

        // Get the page to extract CSRF token
        let csrfToken = try await getCSRFToken(baseURL: baseURL, path: path)

        // Submit post
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw TohrayError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        addCookies(to: &request)

        let formData = [
            "content": content,
            "slug": slug,
            "CSRFToken": csrfToken
        ]

        request.httpBody = urlEncodedForm(formData)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TohrayError.invalidResponse
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 302 else {
            throw TohrayError.postFailed("HTTP \(httpResponse.statusCode)")
        }

        return "\(baseURL)/\(slug)"
    }

    private func urlEncodedForm(_ fields: [String: String]) -> Data? {
        let allowed = CharacterSet.alphanumerics
        let encoded = fields
            .map { key, value in
                "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
            }
            .joined(separator: "&")
        return encoded.data(using: .utf8)
    }

    private func login(baseURL: String, username: String, password: String) async throws -> [HTTPCookie] {
        // Get login page to extract CSRF token
        let csrfToken = try await getCSRFToken(baseURL: baseURL, path: "/login")

        // Submit login
        guard let url = URL(string: "\(baseURL)/login") else {
            throw TohrayError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let formData = [
            "username": username,
            "password": password,
            "CSRFToken": csrfToken
        ]

        request.httpBody = urlEncodedForm(formData)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TohrayError.invalidResponse
        }

        // Store cookies
        if let headerFields = httpResponse.allHeaderFields as? [String: String],
           let url = response.url {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
            self.cookies = cookies
        }

        // Check for login errors
        let html = String(data: data, encoding: .utf8) ?? ""
        if html.contains("Incorrect") {
            throw TohrayError.loginFailed("Incorrect username or password")
        }

        return cookies
    }

    private func getCSRFToken(baseURL: String, path: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw TohrayError.invalidURL
        }

        var request = URLRequest(url: url)
        addCookies(to: &request)

        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? ""

        // Extract CSRF token using regex
        let pattern = #"name="CSRFToken"\s+value="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            throw TohrayError.csrfTokenNotFound
        }

        return String(html[range])
    }

    private func addCookies(to request: inout URLRequest) {
        if !cookies.isEmpty {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
    }
}

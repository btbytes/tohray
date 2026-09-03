import CryptoKit
import Foundation

enum S3Error: LocalizedError {
    case notConfigured
    case invalidEndpoint
    case invalidURL
    case invalidResponse(Int?, String)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "S3 storage is not configured. Add bucket details in Settings."
        case .invalidEndpoint:
            return "The S3 endpoint is not a valid URL."
        case .invalidURL:
            return "Could not build an upload URL from the S3 configuration."
        case .invalidResponse(let code, let body):
            let status = code.map { String($0) } ?? "unknown"
            return "S3 upload failed (HTTP \(status)). \(body)"
        case .encodingFailed:
            return "Could not encode the file data."
        }
    }
}

/// Uploads objects to any S3-compatible endpoint using AWS Signature V4.
struct S3Uploader {
    /// Uploads `data` under `key` (a fully-qualified object key) and returns the
    /// resulting public URL.
    func upload(data: Data, key: String, contentType: String, config: S3Config) async throws -> URL {
        guard config.isConfigured else { throw S3Error.notConfigured }
        guard let uploadURL = makeUploadURL(key: key, config: config) else {
            throw S3Error.invalidURL
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        Authorization(config: config, httpMethod: "PUT", url: uploadURL, contentType: contentType, data: data)
            .apply(to: &request)

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw S3Error.invalidResponse(nil, "No HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: responseData, encoding: .utf8) ?? ""
            throw S3Error.invalidResponse(http.statusCode, body)
        }

        guard let publicURL = config.publicURL(for: key) else {
            throw S3Error.invalidURL
        }
        return publicURL
    }

    /// Verifies the configuration by uploading a tiny test object.
    func testConnection(config: S3Config) async throws {
        let key = config.objectKey(for: "tohray-test.txt")
        let data = Data("tohray connectivity check".utf8)
        _ = try await upload(data: data, key: key, contentType: "text/plain", config: config)
    }

    private func makeUploadURL(key: String, config: S3Config) -> URL? {
        if config.usesVirtualHostedStyle,
           let raw = URL(string: config.endpoint),
           let host = raw.host {
            var components = URLComponents()
            components.scheme = raw.scheme
            components.host = "\(config.bucket).\(host)"
            components.path = "/" + key
            return components.url
        }
        let base = config.endpoint.hasSuffix("/") ? config.endpoint : config.endpoint + "/"
        return URL(string: base + config.bucket + "/" + key)
    }
}

/// Builds and applies an AWS Signature V4 Authorization header.
private struct Authorization {
    let config: S3Config
    let httpMethod: String
    let url: URL
    let contentType: String
    let data: Data

    func apply(to request: inout URLRequest) {
        let now = Date()
        let amzDate = Self.amazonDate(now)
        let dateStamp = String(amzDate.prefix(8))
        let region = config.region
        let service = "s3"
        let scope = "\(dateStamp)/\(region)/\(service)/aws4_request"

        let payloadHash = SHA256.hash(data: data).hex
        let host = Self.hostHeader(for: url)

        var headers: [(String, String)] = [
            ("host", host),
            ("content-type", contentType),
            ("x-amz-content-sha256", payloadHash),
            ("x-amz-date", amzDate)
        ]
        if !config.acl.isEmpty {
            headers.append(("x-amz-acl", config.acl))
        }
        if !config.sessionToken.isEmpty {
            headers.append(("x-amz-security-token", config.sessionToken))
        }

        let sortedHeaders = headers
            .sorted { $0.0 < $1.0 }
        let canonicalHeadersString = sortedHeaders
            .map { "\($0.0):\($0.1)\n" }
            .joined()
        let signedHeaders = sortedHeaders.map { $0.0 }.joined(separator: ";")

        let canonicalQuery = url.queryComponents()
            .map { "\($0.key.awsURIEncode)=\($0.value.awsURIEncode)" }
            .sorted()
            .joined(separator: "&")

        let canonicalRequest = [
            httpMethod,
            url.normalizedPath.awsURIEncode,
            canonicalQuery,
            canonicalHeadersString,
            signedHeaders,
            payloadHash
        ].joined(separator: "\n")

        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            scope,
            SHA256.hash(data: Data(canonicalRequest.utf8)).hex
        ].joined(separator: "\n")

        let signingKey = Self.deriveKey(secret: config.secretAccessKey, date: dateStamp, region: region, service: service)
        let signature = Data(HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: signingKey)).hex

        let authorization = "AWS4-HMAC-SHA256 Credential=\(config.accessKeyID)/\(scope), SignedHeaders=\(signedHeaders), Signature=\(signature)"

        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        request.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")
        if !config.acl.isEmpty {
            request.setValue(config.acl, forHTTPHeaderField: "x-amz-acl")
        }
        if !config.sessionToken.isEmpty {
            request.setValue(config.sessionToken, forHTTPHeaderField: "x-amz-security-token")
        }
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
    }

    /// The `Host` header value, including the port only when it is non-default.
    private static func hostHeader(for url: URL) -> String {
        guard let host = url.host else { return "" }
        if let port = url.port,
           !(url.scheme == "https" && port == 443),
           !(url.scheme == "http" && port == 80) {
            return "\(host):\(port)"
        }
        return host
    }

    /// Formats a date as AWS's `yyyymmdd'T'HHmmss'Z'`.
    private static func amazonDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    private static func deriveKey(secret: String, date: String, region: String, service: String) -> SymmetricKey {
        func hmac(_ key: Data, _ text: String) -> Data {
            Data(HMAC<SHA256>.authenticationCode(for: Data(text.utf8), using: SymmetricKey(data: key)))
        }
        let kDate = hmac(Data("AWS4\(secret)".utf8), date)
        let kRegion = hmac(kDate, region)
        let kService = hmac(kRegion, service)
        return SymmetricKey(data: hmac(kService, "aws4_request"))
    }
}

extension URL {
    /// Returns the path for signing. An empty path must be treated as "/".
    var normalizedPath: String {
        path.isEmpty ? "/" : path
    }

    /// Splits the raw query into (key, value) pairs, preserving order.
    func queryComponents() -> [(key: String, value: String)] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return [] }
        return items.map { ($0.name, $0.value ?? "") }
    }
}

private extension String {
    /// Percent-encodes using the RFC 3986 set that AWS expects, leaving the
    /// unreserved characters and the forward slash (for path components) intact.
    var awsURIEncode: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = addingPercentEncoding(withAllowedCharacters: allowed) ?? self
        // addingPercentEncoding encodes "/" too; AWS wants "/" kept in paths.
        return encoded.replacingOccurrences(of: "%2F", with: "/")
            .replacingOccurrences(of: "%2f", with: "/")
    }
}

private extension Sequence where Element == UInt8 {
    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

import Foundation

/// A single S3-compatible storage configuration. Mirrors the rclone-style
/// `type = s3` block so switching between Cloudflare R2, AWS, and MinIO is a
/// matter of filling in the same familiar fields.
struct S3Config: Equatable {
    var provider = "Cloudflare"
    var accessKeyID = ""
    var secretAccessKey = ""
    var sessionToken = ""
    var endpoint = ""
    var acl = "private"
    var publicURL = ""
    var rootDir = "/appname/"
    var bucket = ""

    static let providers = ["Cloudflare", "AWS", "MinIO", "GenericS3"]
    static let aclOptions = ["private", "public-read"]

    /// Returns true when the credentials required to actually upload are present.
    var isConfigured: Bool {
        !accessKeyID.isEmpty
            && !secretAccessKey.isEmpty
            && !endpoint.isEmpty
            && !bucket.isEmpty
    }

    /// A human-readable explanation of why the endpoint is unusable, or nil if
    /// it is well-formed (or empty, which is handled elsewhere).
    var endpointIssue: String? {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed != endpoint {
            return "The endpoint has leading or trailing whitespace. It will fail to parse."
        }
        guard let url = URL(string: trimmed) else {
            return "The endpoint is not a valid URL."
        }
        if url.scheme == nil {
            return "The endpoint must include a scheme, e.g. https://."
        }
        if url.host == nil {
            return "The endpoint is missing a hostname."
        }
        return nil
    }

    /// The outcome of trying to build an upload URL for an object key: either
    /// the URL, or the precise reason construction failed.
    enum UploadURLResult: Equatable {
        case success(URL)
        case failure(String)
    }

    /// Builds the HTTP PUT endpoint for an object key, or explains why it could
    /// not be built. The reason is always in step with the construction logic so
    /// diagnostics never report a misleading "unknown".
    func uploadURL(for key: String) -> UploadURLResult {
        if !isConfigured {
            return .failure("required fields empty (Access Key ID, Secret Access Key, Endpoint, and Bucket must all be set)")
        }
        if let issue = endpointIssue {
            return .failure(issue)
        }
        guard let raw = URL(string: endpoint), let host = raw.host else {
            return .failure("endpoint is not a valid URL with a hostname")
        }

        if usesVirtualHostedStyle {
            var components = URLComponents()
            components.scheme = raw.scheme
            components.host = "\(bucket).\(host)"
            components.percentEncodedPath = "/" + encodedKeyPath(key)
            if let url = components.url {
                return .success(url)
            }
            return .failure("could not form a virtual-hosted URL from bucket '\(bucket)' and endpoint '\(host)'")
        }

        guard var base = URL(string: endpoint) else {
            return .failure("endpoint is not a valid URL")
        }
        base.appendPathComponent(bucket, isDirectory: true)
        base.appendPathComponent(key, isDirectory: false)
        return .success(base)
    }

    /// The S3 signing region. Cloudflare R2 always uses `auto`; AWS typically
    /// embeds the region in the endpoint host (e.g. s3.<region>.amazonaws.com).
    var region: String {
        if provider == "Cloudflare" {
            return "auto"
        }
        if let host = URL(string: endpoint)?.host,
           let range = host.range(of: "s3."),
           let regionStart = host.index(range.upperBound, offsetBy: 0, limitedBy: host.endIndex) {
            let remainder = host[regionStart...]
            if let dot = remainder.firstIndex(of: ".") {
                return String(remainder[..<dot])
            }
        }
        return "us-east-1"
    }

    /// Object key (path inside the bucket) for a given filename. Joins the
    /// configured root directory with the file name, normalising slashes.
    func objectKey(for filename: String) -> String {
        let prefix = rootDir
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let name = filename.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if prefix.isEmpty {
            return name
        }
        return "\(prefix)/\(name)"
    }

    /// True when uploads should use virtual-hosted style addressing
    /// (`https://<bucket>.<endpoint-host>/<key>`), as Cloudflare R2 does.
    /// Otherwise requests go path-style to `<endpoint>/<bucket>/<key>` (MinIO,
    /// many self-hosted gateways).
    var usesVirtualHostedStyle: Bool {
        guard let host = URL(string: endpoint)?.host else { return false }
        return provider == "Cloudflare" || host.contains(".r2.cloudflarestorage.com")
    }

    /// The endpoint host with any leading scheme stripped, for building the
    /// virtual-hosted URL.
    var endpointHost: String? {
        URL(string: endpoint)?.host
    }

    /// The fully-qualified URL an uploaded object will be publicly reachable at.
    /// Prefers the user-supplied public URL; falls back to deriving one from the
    /// endpoint and bucket. Returns nil only if the base URL is unusable.
    func publicURL(for key: String) -> URL? {
        let encodedKey = encodedKeyPath(key)

        if !publicURL.isEmpty {
            guard var base = URL(string: publicURL) else { return nil }
            base.appendPathComponent(key, isDirectory: false)
            return base
        }

        if usesVirtualHostedStyle, let host = endpointHost, let scheme = URL(string: endpoint)?.scheme {
            var components = URLComponents()
            components.scheme = scheme
            components.host = "\(bucket).\(host)"
            components.percentEncodedPath = "/" + encodedKey
            return components.url
        }

        guard var base = URL(string: endpoint) else { return nil }
        base.appendPathComponent(bucket, isDirectory: true)
        base.appendPathComponent(key, isDirectory: false)
        return base
    }

    /// Percent-encodes a path segment so characters like spaces, `#`, `?`, and
    /// `%` don't break `URL(String:)` parsing.
    func encodedKeyPath(_ key: String) -> String {
        let allowed = CharacterSet.urlPathAllowed
        // urlPathAllowed keeps "/" — fine for nested keys, and it is the
        // conventional separator here.
        return key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
    }

    /// A multi-line diagnostic report describing the configuration and the
    /// constructed upload URL, used when an upload or config test fails. When
    /// `filename` is nil only the configuration is described (no object key).
    func diagnosticReport(for filename: String? = nil) -> String {
        let key = filename.map(objectKey(for:))
        let uploadURLText: String
        if let key {
            switch uploadURL(for: key) {
            case .success(let url): uploadURLText = url.absoluteString
            case .failure(let reason): uploadURLText = "(could not construct — \(reason))"
            }
        } else {
            uploadURLText = "(no object — config test only)"
        }
        let publicURLText: String
        if let key {
            publicURLText = self.publicURL(for: key)?.absoluteString ?? "(could not construct)"
        } else {
            publicURLText = "(no object — config test only)"
        }

        var report: [String] = []
        report.append("Provider: \(provider)")
        report.append("Access Key ID: \(accessKeyID.isEmpty ? "(empty)" : accessKeyID)")
        report.append("Secret Access Key: \(secretAccessKey.isEmpty ? "(empty)" : "••••••\(min(secretAccessKey.count, 4))")")
        report.append("Session Token: \(sessionToken.isEmpty ? "(empty)" : "•\(min(sessionToken.count, 4))")")
        report.append("Endpoint: \(endpoint.isEmpty ? "(empty)" : endpoint)")
        report.append("ACL: \(acl.isEmpty ? "(empty)" : acl)")
        report.append("Bucket: \(bucket.isEmpty ? "(empty)" : bucket)")
        report.append("Root Dir: \(rootDir.isEmpty ? "(empty)" : rootDir)")
        report.append("Public URL: \(publicURL.isEmpty ? "(empty)" : publicURL)")
        report.append("Region: \(region)")
        if let key {
            report.append("Object Key: \(key)")
        }
        report.append("Upload URL: \(uploadURLText)")
        report.append("Public File URL: \(publicURLText)")
        if let issue = endpointIssue {
            report.append("Endpoint issue: \(issue)")
        }
        if !isConfigured {
            report.append("Config issue: missing required fields (Access Key ID, Secret Access Key, Endpoint, and Bucket must all be set).")
        }
        return report.joined(separator: "\n")
    }
}

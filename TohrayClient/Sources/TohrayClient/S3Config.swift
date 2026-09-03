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
    /// endpoint and bucket.
    func publicURL(for key: String) -> URL? {
        if !publicURL.isEmpty {
            let base = publicURL.hasSuffix("/") ? publicURL : publicURL + "/"
            return URL(string: base + key)
        }
        if usesVirtualHostedStyle, let host = endpointHost, let scheme = URL(string: endpoint)?.scheme {
            return URL(string: "\(scheme)://\(bucket).\(host)/\(key)")
        }
        let base = endpoint.hasSuffix("/") ? endpoint : endpoint + "/"
        return URL(string: base + bucket + "/" + key)
    }
}

import Foundation

/// Where a repository lives, parsed from a URL the user pasted.
/// `kind` is nil for hosts that are not one of the well-known public forges;
/// the caller resolves it by probing the host or by asking the user.
public struct ForgeLocation: Equatable, Codable {
    public let scheme: String
    public let host: String
    public let pathComponents: [String]
    public let kind: ForgeKind?

    private static let wellKnownHosts: [String: ForgeKind] = [
        "github.com": .github,
        "gitlab.com": .gitlab,
        "codeberg.org": .forgejo,
    ]

    private static let gitLabPathSeparator = "-"
    private static let minimumPathComponents = 2

    public init(scheme: String, host: String, pathComponents: [String], kind: ForgeKind?) {
        self.scheme = scheme
        self.host = host
        self.pathComponents = pathComponents
        self.kind = kind
    }

    public init(parsing text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard
            let components = URLComponents(string: withScheme),
            let scheme = components.scheme?.lowercased(),
            let host = components.host?.lowercased()
        else {
            throw ForgeError.invalidRepositoryURL(text)
        }

        var path = components.path.split(separator: "/").map(String.init)
        if let separatorIndex = path.firstIndex(of: Self.gitLabPathSeparator) {
            path = Array(path[..<separatorIndex])
        }
        if let last = path.last, last.hasSuffix(".git") {
            path[path.count - 1] = String(last.dropLast(".git".count))
        }
        guard path.count >= Self.minimumPathComponents else {
            throw ForgeError.invalidRepositoryURL(text)
        }

        let authority = components.port.map { "\(host):\($0)" } ?? host
        self.init(scheme: scheme, host: authority, pathComponents: path, kind: Self.wellKnownHosts[host])
    }

    public func with(kind: ForgeKind) -> ForgeLocation {
        ForgeLocation(scheme: scheme, host: host, pathComponents: pathComponents, kind: kind)
    }

    /// `owner/repo` on GitHub and Forgejo; the full group path on GitLab, which allows subgroups.
    public var projectPath: String {
        let used = kind == .gitlab || kind == nil ? pathComponents : Array(pathComponents.prefix(Self.minimumPathComponents))
        return used.joined(separator: "/")
    }

    public var displayName: String {
        "\(host)/\(projectPath)"
    }
}

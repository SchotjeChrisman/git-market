import Foundation

public struct GitHubSource: ReleaseSource {
    private static let publicHost = "github.com"
    private static let publicAPIBase = "https://api.github.com"
    private static let releasesPerPage = 30

    public init() {}

    public func releasesRequest(for location: ForgeLocation, token: String?) throws -> URLRequest {
        let apiBase = location.host == Self.publicHost
            ? Self.publicAPIBase
            : "\(location.scheme)://\(location.host)/api/v3"
        var headers = ["Accept": "application/vnd.github+json"]
        if let token { headers["Authorization"] = "Bearer \(token)" }
        return try makeRequest(
            url: "\(apiBase)/repos/\(location.projectPath)/releases?per_page=\(Self.releasesPerPage)",
            headers: headers
        )
    }

    public func parseReleases(from data: Data) throws -> [Release] {
        try GitHubStyleReleases.parse(data)
    }
}

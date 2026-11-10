import Foundation

public struct ForgejoSource: ReleaseSource {
    private static let releasesPerPage = 30

    public init() {}

    public func releasesRequest(for location: ForgeLocation, token: String?) throws -> URLRequest {
        var headers: [String: String] = [:]
        if let token { headers["Authorization"] = "token \(token)" }
        return try makeRequest(
            url: "\(location.scheme)://\(location.host)/api/v1/repos/\(location.projectPath)/releases?limit=\(Self.releasesPerPage)",
            headers: headers
        )
    }

    public func parseReleases(from data: Data) throws -> [Release] {
        try GitHubStyleReleases.parse(data)
    }
}

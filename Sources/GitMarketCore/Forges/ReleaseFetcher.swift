import Foundation

public struct ReleaseFetcher {
    private static let okStatus = 200

    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient = .live) {
        self.httpClient = httpClient
    }

    public func fetchReleases(from location: ForgeLocation, token: String?) async throws -> [Release] {
        guard let kind = location.kind else { throw ForgeError.unknownForge(host: location.host) }
        let source = ReleaseSources.source(for: kind)
        let request = try source.releasesRequest(for: location, token: token)
        let (data, response) = try await httpClient.send(request)
        guard response.statusCode == Self.okStatus else {
            throw ForgeError.http(status: response.statusCode)
        }
        return try source.parseReleases(from: data)
    }

    /// Asks a self-hosted host which forge it runs: Forgejo/Gitea answer on `/api/v1/version`,
    /// GitLab on `/api/v4/version` (which wants a token, so 401 still proves it is GitLab).
    public func detectKind(of location: ForgeLocation) async -> ForgeKind? {
        if let kind = location.kind { return kind }
        let probes: [(path: String, kind: ForgeKind, acceptedStatuses: Set<Int>)] = [
            ("/api/v1/version", .forgejo, [200]),
            ("/api/v4/version", .gitlab, [200, 401]),
        ]
        for probe in probes {
            guard let url = URL(string: "\(location.scheme)://\(location.host)\(probe.path)") else { continue }
            guard let (_, response) = try? await httpClient.send(URLRequest(url: url)) else { continue }
            if probe.acceptedStatuses.contains(response.statusCode) { return probe.kind }
        }
        return nil
    }
}

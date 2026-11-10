import Foundation

public struct GitLabSource: ReleaseSource {
    private static let releasesPerPage = 30
    private static let pathAllowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))

    private struct ReleaseDTO: Decodable {
        let tag_name: String
        let name: String?
        let upcoming_release: Bool
        let released_at: String?
        let _links: LinksDTO?
        let assets: AssetsDTO
    }

    private struct LinksDTO: Decodable {
        let `self`: URL?
    }

    private struct AssetsDTO: Decodable {
        let links: [LinkDTO]
    }

    private struct LinkDTO: Decodable {
        let name: String
        let url: URL
        let direct_asset_url: URL?
    }

    public init() {}

    public func releasesRequest(for location: ForgeLocation, token: String?) throws -> URLRequest {
        guard let encodedPath = location.projectPath.addingPercentEncoding(withAllowedCharacters: Self.pathAllowedCharacters) else {
            throw ForgeError.invalidRepositoryURL(location.displayName)
        }
        var headers: [String: String] = [:]
        if let token { headers["PRIVATE-TOKEN"] = token }
        return try makeRequest(
            url: "\(location.scheme)://\(location.host)/api/v4/projects/\(encodedPath)/releases?per_page=\(Self.releasesPerPage)",
            headers: headers
        )
    }

    public func parseReleases(from data: Data) throws -> [Release] {
        let releases: [ReleaseDTO]
        do {
            releases = try JSONDecoder().decode([ReleaseDTO].self, from: data)
        } catch {
            throw ForgeError.malformedResponse
        }
        return releases.map { dto in
            Release(
                tag: dto.tag_name,
                name: dto.name,
                isPrerelease: dto.upcoming_release,
                publishedAt: ReleaseDateParser.parse(dto.released_at),
                pageURL: dto._links?.self,
                assets: dto.assets.links.map {
                    Asset(name: $0.name, size: nil, downloadURL: $0.direct_asset_url ?? $0.url)
                }
            )
        }
    }
}

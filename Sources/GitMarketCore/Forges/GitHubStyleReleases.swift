import Foundation

/// GitHub and Forgejo/Gitea return the same release shape, so they share one parser.
enum GitHubStyleReleases {
    private struct ReleaseDTO: Decodable {
        let tag_name: String
        let name: String?
        let prerelease: Bool
        let draft: Bool
        let published_at: String?
        let html_url: URL?
        let assets: [AssetDTO]
    }

    private struct AssetDTO: Decodable {
        let name: String
        let size: Int?
        let browser_download_url: URL
    }

    static func parse(_ data: Data) throws -> [Release] {
        let releases: [ReleaseDTO]
        do {
            releases = try JSONDecoder().decode([ReleaseDTO].self, from: data)
        } catch {
            throw ForgeError.malformedResponse
        }
        return releases.filter { !$0.draft }.map { dto in
            Release(
                tag: dto.tag_name,
                name: dto.name,
                isPrerelease: dto.prerelease,
                publishedAt: ReleaseDateParser.parse(dto.published_at),
                pageURL: dto.html_url,
                assets: dto.assets.map {
                    Asset(name: $0.name, size: $0.size, downloadURL: $0.browser_download_url)
                }
            )
        }
    }
}

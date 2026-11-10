import Foundation

public struct Asset: Equatable, Codable {
    public let name: String
    public let size: Int?
    public let downloadURL: URL

    public init(name: String, size: Int?, downloadURL: URL) {
        self.name = name
        self.size = size
        self.downloadURL = downloadURL
    }
}

public struct Release: Equatable, Codable {
    public let tag: String
    public let name: String?
    public let isPrerelease: Bool
    public let publishedAt: Date?
    public let pageURL: URL?
    public let assets: [Asset]

    public init(
        tag: String,
        name: String?,
        isPrerelease: Bool,
        publishedAt: Date?,
        pageURL: URL?,
        assets: [Asset]
    ) {
        self.tag = tag
        self.name = name
        self.isPrerelease = isPrerelease
        self.publishedAt = publishedAt
        self.pageURL = pageURL
        self.assets = assets
    }
}

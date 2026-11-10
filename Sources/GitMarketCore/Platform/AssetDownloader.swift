import Foundation

/// The download edge. It returns a file inside a fresh folder that the caller may delete afterwards.
/// No token is sent: release downloads usually redirect to another host, and a token must not follow.
public struct AssetDownloader {
    private static let okStatus = 200

    public var download: (Asset) async throws -> URL

    public init(download: @escaping (Asset) async throws -> URL) {
        self.download = download
    }

    public static let live = AssetDownloader { asset in
        let (temporaryFile, response) = try await URLSession.shared.download(from: asset.downloadURL)
        guard let httpResponse = response as? HTTPURLResponse else { throw ForgeError.malformedResponse }
        guard httpResponse.statusCode == okStatus else { throw ForgeError.http(status: httpResponse.statusCode) }

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("GitMarketDownload-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent((asset.name as NSString).lastPathComponent)
        try FileManager.default.moveItem(at: temporaryFile, to: target)
        return target
    }
}

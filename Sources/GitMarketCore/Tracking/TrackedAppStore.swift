import Foundation

/// The list of tracked apps as one JSON file. A missing file is an empty list; a corrupt one is an error.
public struct TrackedAppStore {
    public static var defaultFileURL: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent(AppIdentity.displayName, isDirectory: true)
            .appendingPathComponent("apps.json")
    }

    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL = TrackedAppStore.defaultFileURL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func load() throws -> [TrackedApp] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([TrackedApp].self, from: Data(contentsOf: fileURL))
    }

    public func save(_ apps: [TrackedApp]) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(apps).write(to: fileURL, options: .atomic)
    }
}

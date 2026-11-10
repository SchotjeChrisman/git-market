import Foundation

enum AppBundleLocator {
    /// Finds the app in an extracted archive or mounted image: at the top level, else one folder down.
    static func find(in directory: URL, fileManager: FileManager = .default) throws -> URL {
        let entries = try visibleEntries(of: directory, fileManager: fileManager)
        if let app = entries.first(where: isAppBundle) { return app }
        for folder in entries where isDirectory(folder) {
            if let app = try visibleEntries(of: folder, fileManager: fileManager).first(where: isAppBundle) {
                return app
            }
        }
        throw InstallError.noAppBundleFound
    }

    private static func visibleEntries(of directory: URL, fileManager: FileManager) throws -> [URL] {
        try fileManager
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func isAppBundle(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "app"
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}

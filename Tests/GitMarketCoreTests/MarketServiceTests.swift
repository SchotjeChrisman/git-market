import XCTest
@testable import GitMarketCore

final class MarketServiceTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    private func httpClient(serving json: String) -> HTTPClient {
        HTTPClient { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(json.utf8), response)
        }
    }

    private func releaseJSON(tag: String, assetName: String) -> String {
        """
        [{"tag_name":"\(tag)","name":null,"prerelease":false,"draft":false,
          "published_at":"2026-11-01T00:00:00Z","html_url":null,
          "assets":[{"name":"\(assetName)","size":1,"browser_download_url":"https://example.com/\(assetName)"}]}]
        """
    }

    private func makeService(
        releases json: String,
        installDirectory: URL,
        downloader: AssetDownloader = AssetDownloader { _ in throw CocoaError(.fileNoSuchFile) }
    ) -> MarketService {
        MarketService(
            fetcher: ReleaseFetcher(httpClient: httpClient(serving: json)),
            downloader: downloader,
            installer: Installer(installDirectory: installDirectory, terminateRunningApp: { _ in }),
            tokenForHost: { _ in nil },
            now: { self.fixedNow },
            architecture: .arm64
        )
    }

    func testPreviewPicksLatestReleaseAndItsAsset() async throws {
        let service = makeService(releases: releaseJSON(tag: "v3.1.0", assetName: "Tool-3.1.0.dmg"), installDirectory: try makeTemporaryDirectory())
        let preview = try await service.preview(repositoryText: "github.com/owner/tool")
        XCTAssertEqual(preview.release.tag, "v3.1.0")
        XCTAssertEqual(preview.asset.name, "Tool-3.1.0.dmg")
        XCTAssertEqual(preview.location.kind, .github)
    }

    func testPreviewReportsReleaseWithoutMacAsset() async throws {
        let service = makeService(releases: releaseJSON(tag: "v1", assetName: "tool-linux.zip"), installDirectory: try makeTemporaryDirectory())
        do {
            _ = try await service.preview(repositoryText: "github.com/owner/tool")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? MarketError, .noInstallableAsset(tag: "v1"))
        }
    }

    func testCheckRecordsLatestTagAndTime() async throws {
        let service = makeService(releases: releaseJSON(tag: "v2.0.0", assetName: "Tool.dmg"), installDirectory: try makeTemporaryDirectory())
        var app = TrackedApp(location: try ForgeLocation(parsing: "github.com/owner/tool"), displayName: "Tool")
        app.installedTag = "v1.0.0"
        let checked = try await service.check(app)
        XCTAssertEqual(checked.latestKnownTag, "v2.0.0")
        XCTAssertEqual(checked.lastCheckedAt, fixedNow)
        XCTAssertTrue(checked.hasUpdate)
    }

    func testInstallDownloadsInstallsAndRecordsTheTag() async throws {
        let work = try makeTemporaryDirectory()
        let applications = work.appendingPathComponent("Applications")
        let zip = try await makeZippedUnsignedApp(named: "Fresh", in: work)
        let downloader = AssetDownloader { _ in
            let folder = work.appendingPathComponent("download-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let copy = folder.appendingPathComponent("Fresh.zip")
            try FileManager.default.copyItem(at: zip, to: copy)
            return copy
        }
        let service = makeService(releases: releaseJSON(tag: "v1.2.3", assetName: "Fresh.zip"), installDirectory: applications, downloader: downloader)
        let app = TrackedApp(location: try ForgeLocation(parsing: "github.com/owner/fresh"), displayName: "Fresh")

        let installed = try await service.install(app)

        XCTAssertEqual(installed.installedTag, "v1.2.3")
        XCTAssertEqual(installed.installedSignature, .adHoc)
        XCTAssertEqual(installed.installedBundlePath, applications.appendingPathComponent("Fresh.app").path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: applications.appendingPathComponent("Fresh.app").path))
        XCTAssertFalse(installed.hasUpdate)
    }

    private func makeZippedUnsignedApp(named name: String, in directory: URL) async throws -> URL {
        let app = directory.appendingPathComponent("src/\(name).app")
        let executableDirectory = app.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: executableDirectory, withIntermediateDirectories: true)
        let executable = executableDirectory.appendingPathComponent(name)
        try "#!/bin/sh\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
        <key>CFBundleExecutable</key><string>\(name)</string>
        <key>CFBundleIdentifier</key><string>dev.gitmarket.test.\(name)</string>
        <key>CFBundlePackageType</key><string>APPL</string>
        </dict></plist>
        """
        try plist.write(to: app.appendingPathComponent("Contents/Info.plist"), atomically: true, encoding: .utf8)

        let zip = directory.appendingPathComponent("\(name)-source.zip")
        _ = try await ProcessRunner.live.runChecked(Command("/usr/bin/ditto", ["-c", "-k", "--keepParent", app.path, zip.path]))
        return zip
    }
}

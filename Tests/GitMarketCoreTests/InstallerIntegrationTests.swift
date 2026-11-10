import XCTest
@testable import GitMarketCore

/// Runs the real macOS tools (ditto, hdiutil, xattr, codesign) on a small unsigned app built on the fly.
final class InstallerIntegrationTests: XCTestCase {
    private let runner = ProcessRunner.live

    private func makeUnsignedApp(named name: String, marker: String, in directory: URL) throws -> URL {
        let app = directory.appendingPathComponent("\(name).app")
        let executableDirectory = app.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: executableDirectory, withIntermediateDirectories: true)

        let executable = executableDirectory.appendingPathComponent(name)
        try "#!/bin/sh\necho \(marker)\n".write(to: executable, atomically: true, encoding: .utf8)
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
        return app
    }

    private func makeZip(of app: URL, in directory: URL) async throws -> URL {
        let zip = directory.appendingPathComponent("\(app.deletingPathExtension().lastPathComponent).zip")
        _ = try await runner.runChecked(Command("/usr/bin/ditto", ["-c", "-k", "--keepParent", app.path, zip.path]))
        return zip
    }

    private func makeDiskImage(of app: URL, in directory: URL) async throws -> URL {
        let folder = directory.appendingPathComponent("image-contents")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: app, to: folder.appendingPathComponent(app.lastPathComponent))
        let image = directory.appendingPathComponent("\(app.deletingPathExtension().lastPathComponent).dmg")
        _ = try await runner.runChecked(Command("/usr/bin/hdiutil", ["create", "-srcfolder", folder.path, "-format", "UDZO", "-quiet", image.path]))
        return image
    }

    private func marker(ofInstalledApp bundle: URL, named name: String) throws -> String {
        try String(contentsOf: bundle.appendingPathComponent("Contents/MacOS/\(name)"), encoding: .utf8)
    }

    private func assertInstalled(_ outcome: InstallOutcome, marker: String, name: String) async throws {
        let bundle = try XCTUnwrap(outcome.bundleURL)
        XCTAssertTrue(try self.marker(ofInstalledApp: bundle, named: name).contains(marker))
        XCTAssertEqual(outcome.signature, .adHoc)

        let quarantine = try await runner.run(Command("/usr/bin/xattr", ["-p", "com.apple.quarantine", bundle.path]))
        XCTAssertNotEqual(quarantine.status, 0, "quarantine flag should be gone")
        let verification = try await runner.run(InstallCommands.verifySignature(of: bundle))
        XCTAssertEqual(verification.status, 0, verification.standardError)
    }

    func testInstallsUnsignedAppFromZipThenReplacesItOnUpdate() async throws {
        let work = try makeTemporaryDirectory()
        let installDirectory = work.appendingPathComponent("Applications")
        let installer = Installer(installDirectory: installDirectory, terminateRunningApp: { _ in })

        let first = try makeUnsignedApp(named: "Zippy", marker: "one", in: work.appendingPathComponent("v1"))
        let firstOutcome = try await installer.install(InstallRequest(packageURL: makeZip(of: first, in: work), kind: .archive))
        try await assertInstalled(firstOutcome, marker: "one", name: "Zippy")

        let second = try makeUnsignedApp(named: "Zippy", marker: "two", in: work.appendingPathComponent("v2"))
        let secondOutcome = try await installer.install(InstallRequest(packageURL: makeZip(of: second, in: work.appendingPathComponent("v2")), kind: .archive))
        try await assertInstalled(secondOutcome, marker: "two", name: "Zippy")
    }

    func testInstallsUnsignedAppFromDiskImage() async throws {
        let work = try makeTemporaryDirectory()
        let installer = Installer(installDirectory: work.appendingPathComponent("Applications"), terminateRunningApp: { _ in })

        let app = try makeUnsignedApp(named: "Imagey", marker: "disk", in: work.appendingPathComponent("src"))
        let image = try await makeDiskImage(of: app, in: work)
        let outcome = try await installer.install(InstallRequest(packageURL: image, kind: .diskImage))
        try await assertInstalled(outcome, marker: "disk", name: "Imagey")
    }
}

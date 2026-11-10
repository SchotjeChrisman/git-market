import XCTest
@testable import GitMarketCore

final class InstallCommandsTests: XCTestCase {
    func testPackageKindFollowsFileExtension() {
        XCTAssertEqual(PackageKind(fileName: "App-1.0.DMG"), .diskImage)
        XCTAssertEqual(PackageKind(fileName: "App.zip"), .archive)
        XCTAssertEqual(PackageKind(fileName: "App.pkg"), .installerPackage)
        XCTAssertNil(PackageKind(fileName: "App.exe"))
    }

    func testAttachMountsReadOnlyWithoutBrowsingAndAcceptsLicense() {
        let command = InstallCommands.attach(
            image: URL(fileURLWithPath: "/tmp/a.dmg"),
            mountPoint: URL(fileURLWithPath: "/tmp/mnt")
        )
        XCTAssertEqual(command.executable, "/usr/bin/hdiutil")
        XCTAssertEqual(command.arguments, ["attach", "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", "/tmp/mnt", "/tmp/a.dmg"])
        XCTAssertEqual(command.standardInput, "Y\n")
    }

    func testQuarantineRemovalIsRecursiveAndTargetsOnlyThatAttribute() {
        let command = InstallCommands.removeQuarantine(from: URL(fileURLWithPath: "/tmp/App.app"))
        XCTAssertEqual(command.arguments, ["-dr", "com.apple.quarantine", "/tmp/App.app"])
    }

    func testPackageInstallRunsInstallerWithAdministratorPrivileges() {
        let command = InstallCommands.installPackage(URL(fileURLWithPath: "/tmp/work/package.pkg"))
        XCTAssertEqual(command.executable, "/usr/bin/osascript")
        XCTAssertEqual(
            command.arguments,
            ["-e", "do shell script \"/usr/sbin/installer -pkg /tmp/work/package.pkg -target /\" with administrator privileges"]
        )
    }
}

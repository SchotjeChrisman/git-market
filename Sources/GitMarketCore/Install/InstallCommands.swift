import Foundation

/// The exact macOS tool invocations the installer uses, kept pure so they can be checked without running them.
enum InstallCommands {
    private static let acceptLicensePrompt = "Y\n"
    private static let quarantineAttribute = "com.apple.quarantine"

    static func attach(image: URL, mountPoint: URL) -> Command {
        Command(
            "/usr/bin/hdiutil",
            ["attach", "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mountPoint.path, image.path],
            standardInput: acceptLicensePrompt
        )
    }

    static func detach(mountPoint: URL) -> Command {
        Command("/usr/bin/hdiutil", ["detach", mountPoint.path])
    }

    static func extract(archive: URL, into directory: URL) -> Command {
        Command("/usr/bin/ditto", ["-x", "-k", archive.path, directory.path])
    }

    static func copyBundle(from source: URL, to destination: URL) -> Command {
        Command("/usr/bin/ditto", [source.path, destination.path])
    }

    static func removeQuarantine(from bundle: URL) -> Command {
        Command("/usr/bin/xattr", ["-dr", quarantineAttribute, bundle.path])
    }

    static func verifySignature(of bundle: URL) -> Command {
        Command("/usr/bin/codesign", ["--verify", "--deep", "--strict", bundle.path])
    }

    static func adHocSign(_ bundle: URL) -> Command {
        Command("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", bundle.path])
    }

    static func describeSignature(of bundle: URL) -> Command {
        Command("/usr/bin/codesign", ["-dv", "--verbose=4", bundle.path])
    }

    /// `pkg` must be a path this app wrote itself, so it needs no AppleScript escaping.
    static func installPackage(_ package: URL) -> Command {
        let shellCommand = "/usr/sbin/installer -pkg \(package.path) -target /"
        return Command("/usr/bin/osascript", ["-e", "do shell script \"\(shellCommand)\" with administrator privileges"])
    }
}

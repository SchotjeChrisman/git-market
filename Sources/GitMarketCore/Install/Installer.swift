import Foundation

public struct InstallRequest {
    public let packageURL: URL
    public let kind: PackageKind
    public let allowSigningTeamChange: Bool

    public init(packageURL: URL, kind: PackageKind, allowSigningTeamChange: Bool = false) {
        self.packageURL = packageURL
        self.kind = kind
        self.allowSigningTeamChange = allowSigningTeamChange
    }
}

public struct InstallOutcome: Equatable {
    /// Nil for `.pkg` files: the installer decides where things go, so only the tag is tracked.
    public let bundleURL: URL?
    public let signature: SignatureInfo?
}

public struct Installer {
    private let runner: ProcessRunner
    private let fileManager: FileManager
    private let installDirectory: URL
    private let terminateRunningApp: (URL) async -> Void

    public init(
        installDirectory: URL,
        runner: ProcessRunner = .live,
        fileManager: FileManager = .default,
        terminateRunningApp: @escaping (URL) async -> Void = RunningApps.terminate
    ) {
        self.installDirectory = installDirectory
        self.runner = runner
        self.fileManager = fileManager
        self.terminateRunningApp = terminateRunningApp
    }

    public func install(_ request: InstallRequest) async throws -> InstallOutcome {
        let workDirectory = fileManager.temporaryDirectory.appendingPathComponent("GitMarket-\(UUID().uuidString)")
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        // Best effort: a leftover temp folder must not hide the real install result.
        defer { try? fileManager.removeItem(at: workDirectory) }

        switch request.kind {
        case .installerPackage:
            try await installPackage(request.packageURL, workDirectory: workDirectory)
            return InstallOutcome(bundleURL: nil, signature: nil)
        case .diskImage:
            let staged = try await stageFromDiskImage(request.packageURL, workDirectory: workDirectory)
            return try await installBundle(staged, allowTeamChange: request.allowSigningTeamChange)
        case .archive:
            let staged = try await stageFromArchive(request.packageURL, workDirectory: workDirectory)
            return try await installBundle(staged, allowTeamChange: request.allowSigningTeamChange)
        }
    }

    private func installPackage(_ package: URL, workDirectory: URL) async throws {
        let safeCopy = workDirectory.appendingPathComponent("package.pkg")
        try fileManager.copyItem(at: package, to: safeCopy)
        _ = try await runner.runChecked(InstallCommands.installPackage(safeCopy))
    }

    private func stageFromArchive(_ archive: URL, workDirectory: URL) async throws -> URL {
        let extracted = workDirectory.appendingPathComponent("extracted")
        try fileManager.createDirectory(at: extracted, withIntermediateDirectories: true)
        _ = try await runner.runChecked(InstallCommands.extract(archive: archive, into: extracted))
        return try AppBundleLocator.find(in: extracted, fileManager: fileManager)
    }

    private func stageFromDiskImage(_ image: URL, workDirectory: URL) async throws -> URL {
        let mountPoint = workDirectory.appendingPathComponent("mount")
        try fileManager.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        _ = try await runner.runChecked(InstallCommands.attach(image: image, mountPoint: mountPoint))

        let staged: URL
        do {
            let mountedApp = try AppBundleLocator.find(in: mountPoint, fileManager: fileManager)
            let stagingDirectory = workDirectory.appendingPathComponent("staged")
            try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
            staged = stagingDirectory.appendingPathComponent(mountedApp.lastPathComponent)
            _ = try await runner.runChecked(InstallCommands.copyBundle(from: mountedApp, to: staged))
        } catch {
            // The copy error is the one worth reporting; a failed detach on top of it is not.
            _ = try? await runner.run(InstallCommands.detach(mountPoint: mountPoint))
            throw error
        }
        _ = try await runner.runChecked(InstallCommands.detach(mountPoint: mountPoint))
        return staged
    }

    private func installBundle(_ staged: URL, allowTeamChange: Bool) async throws -> InstallOutcome {
        let destination = installDirectory.appendingPathComponent(staged.lastPathComponent)
        let inspector = SignatureInspector(runner: runner)

        let incomingSignature = try await inspector.inspect(staged)
        let isReplacing = fileManager.fileExists(atPath: destination.path)
        var installedSignature: SignatureInfo?
        if isReplacing { installedSignature = try await inspector.inspect(destination) }
        if !allowTeamChange, let previousTeam = SigningPolicy.changesTeam(from: installedSignature, to: incomingSignature) {
            throw InstallError.signingTeamChanged(previous: previousTeam, new: incomingSignature)
        }

        _ = try await runner.runChecked(InstallCommands.removeQuarantine(from: staged))
        try await ensureRunnableSignature(staged)

        if isReplacing {
            await terminateRunningApp(destination)
            _ = try fileManager.replaceItemAt(destination, withItemAt: staged)
        } else {
            try fileManager.createDirectory(at: installDirectory, withIntermediateDirectories: true)
            try fileManager.moveItem(at: staged, to: destination)
        }
        return InstallOutcome(bundleURL: destination, signature: try await inspector.inspect(destination))
    }

    /// Apple Silicon refuses unsigned code, and a bundle whose signature no longer verifies is as good as unsigned.
    private func ensureRunnableSignature(_ bundle: URL) async throws {
        let verification = try await runner.run(InstallCommands.verifySignature(of: bundle))
        guard verification.status != 0 else { return }
        _ = try await runner.runChecked(InstallCommands.adHocSign(bundle))
    }
}

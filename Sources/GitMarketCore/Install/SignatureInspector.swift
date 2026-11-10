import Foundation

public struct SignatureInspector {
    private let runner: ProcessRunner

    public init(runner: ProcessRunner = .live) {
        self.runner = runner
    }

    public func inspect(_ bundle: URL) async throws -> SignatureInfo {
        let result = try await runner.run(InstallCommands.describeSignature(of: bundle))
        return SignatureInfo.parse(codesignOutput: result.standardError, exitStatus: result.status)
    }
}

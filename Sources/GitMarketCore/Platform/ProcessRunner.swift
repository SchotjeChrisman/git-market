import Foundation

public struct Command: Equatable {
    public let executable: String
    public let arguments: [String]
    public let standardInput: String?

    public init(_ executable: String, _ arguments: [String], standardInput: String? = nil) {
        self.executable = executable
        self.arguments = arguments
        self.standardInput = standardInput
    }
}

public struct ProcessResult: Equatable {
    public let status: Int32
    public let standardOutput: String
    public let standardError: String

    public init(status: Int32, standardOutput: String, standardError: String) {
        self.status = status
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

/// The process edge. Install logic builds `Command`s and reads `ProcessResult`s.
public struct ProcessRunner {
    public var run: (Command) async throws -> ProcessResult

    public init(run: @escaping (Command) async throws -> ProcessResult) {
        self.run = run
    }

    /// Output goes to temp files, not pipes: `hdiutil attach` leaves a helper running that keeps
    /// inherited pipes open, so waiting for end-of-output would never finish.
    public static let live = ProcessRunner { command in
        let capture = try OutputCapture()
        defer { capture.remove() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.standardOutput = capture.outputHandle
        process.standardError = capture.errorHandle
        let inputPipe = Pipe()
        if let input = command.standardInput {
            inputPipe.fileHandleForWriting.write(Data(input.utf8))
        }
        try inputPipe.fileHandleForWriting.close()
        process.standardInput = inputPipe

        try await runUntilExit(process)

        return ProcessResult(
            status: process.terminationStatus,
            standardOutput: try capture.readOutput(),
            standardError: try capture.readError()
        )
    }

    public func runChecked(_ command: Command) async throws -> ProcessResult {
        let result = try await run(command)
        guard result.status == 0 else {
            throw InstallError.commandFailed(
                tool: command.executable,
                status: result.status,
                message: result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return result
    }
}

private func runUntilExit(_ process: Process) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        process.terminationHandler = { _ in continuation.resume() }
        do {
            try process.run()
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

private struct OutputCapture {
    let outputHandle: FileHandle
    let errorHandle: FileHandle
    private let outputURL: URL
    private let errorURL: URL

    init() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("GitMarketProcess-\(UUID().uuidString)")
        outputURL = base.appendingPathExtension("out")
        errorURL = base.appendingPathExtension("err")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        outputHandle = try FileHandle(forWritingTo: outputURL)
        errorHandle = try FileHandle(forWritingTo: errorURL)
    }

    func readOutput() throws -> String { String(decoding: try Data(contentsOf: outputURL), as: UTF8.self) }
    func readError() throws -> String { String(decoding: try Data(contentsOf: errorURL), as: UTF8.self) }

    func remove() {
        try? outputHandle.close()
        try? errorHandle.close()
        try? FileManager.default.removeItem(at: outputURL)
        try? FileManager.default.removeItem(at: errorURL)
    }
}

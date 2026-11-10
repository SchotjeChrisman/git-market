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

    public static let live = ProcessRunner { command in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = inputPipe

        try process.run()
        if let input = command.standardInput {
            inputPipe.fileHandleForWriting.write(Data(input.utf8))
        }
        try inputPipe.fileHandleForWriting.close()

        async let outputData = readToEnd(outputPipe)
        async let errorData = readToEnd(errorPipe)
        let (output, error) = await (outputData, errorData)
        process.waitUntilExit()
        return ProcessResult(
            status: process.terminationStatus,
            standardOutput: String(decoding: output, as: UTF8.self),
            standardError: String(decoding: error, as: UTF8.self)
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

private func readToEnd(_ pipe: Pipe) async -> Data {
    await Task.detached { pipe.fileHandleForReading.readDataToEndOfFile() }.value
}

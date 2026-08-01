import Foundation

nonisolated struct CommandResult: Sendable {
    let executable: String
    let arguments: [String]
    let standardOutput: String
    let standardError: String
    let exitCode: Int32

    var succeeded: Bool { exitCode == 0 }
}

nonisolated protocol CommandRunning: Sendable {
    func run(executable: String, arguments: [String]) async throws -> CommandResult
}

actor FoundationCommandRunner: CommandRunning {
    func run(executable: String, arguments: [String]) async throws -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        return CommandResult(
            executable: executable,
            arguments: arguments,
            standardOutput: String(decoding: outputData, as: UTF8.self),
            standardError: String(decoding: errorData, as: UTF8.self),
            exitCode: process.terminationStatus
        )
    }
}

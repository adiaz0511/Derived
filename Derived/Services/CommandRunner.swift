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

nonisolated enum CommandRunnerError: Error, Equatable {
    case timedOut(executable: String)
    case missingTerminationStatus(executable: String)
}

extension CommandRunnerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .timedOut(let executable):
            "The command timed out: \(executable)"
        case .missingTerminationStatus(let executable):
            "The command ended without reporting a termination status: \(executable)"
        }
    }
}

actor FoundationCommandRunner: CommandRunning {
    private let timeout: Duration

    init(timeout: Duration = .seconds(60)) {
        self.timeout = timeout
    }

    func run(executable: String, arguments: [String]) async throws -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let terminationStatuses = Self.terminationStatuses(for: process)
        do {
            try process.run()
        } catch {
            try? outputPipe.fileHandleForWriting.close()
            try? errorPipe.fileHandleForWriting.close()
            throw error
        }
        try? outputPipe.fileHandleForWriting.close()
        try? errorPipe.fileHandleForWriting.close()

        async let outputData = Self.readAllBytes(from: outputPipe.fileHandleForReading)
        async let errorData = Self.readAllBytes(from: errorPipe.fileHandleForReading)

        let exitCode = try await Self.waitForTermination(
            of: process,
            statuses: terminationStatuses,
            executable: executable,
            timeout: timeout
        )
        let (standardOutput, standardError) = await (outputData, errorData)

        return CommandResult(
            executable: executable,
            arguments: arguments,
            standardOutput: String(decoding: standardOutput, as: UTF8.self),
            standardError: String(decoding: standardError, as: UTF8.self),
            exitCode: exitCode
        )
    }

    private nonisolated static func terminationStatuses(for process: Process) -> AsyncStream<Int32> {
        AsyncStream { continuation in
            process.terminationHandler = { completedProcess in
                continuation.yield(completedProcess.terminationStatus)
                continuation.finish()
            }
        }
    }

    private nonisolated static func readAllBytes(from handle: FileHandle) async -> Data {
        await Task.detached {
            handle.readDataToEndOfFile()
        }.value
    }

    private nonisolated static func waitForTermination(
        of process: Process,
        statuses: AsyncStream<Int32>,
        executable: String,
        timeout: Duration
    ) async throws -> Int32 {
        try await withThrowingTaskGroup(of: Int32.self) { group in
            group.addTask {
                for await status in statuses {
                    return status
                }
                throw CommandRunnerError.missingTerminationStatus(executable: executable)
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw CommandRunnerError.timedOut(executable: executable)
            }

            do {
                guard let status = try await group.next() else {
                    throw CommandRunnerError.missingTerminationStatus(executable: executable)
                }
                group.cancelAll()
                return status
            } catch {
                if process.isRunning {
                    process.terminate()
                }
                group.cancelAll()
                throw error
            }
        }
    }
}

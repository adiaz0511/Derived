import Darwin
import Foundation

enum CLIProgress {
    static func run<T: Sendable>(
        _ label: String,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let interactive = isatty(STDERR_FILENO) == 1
        guard interactive else {
            write("\(label)...\n")
            return try await operation()
        }

        let task = Task {
            let frames = ["|", "/", "-", "\\"]
            var index = 0
            while !Task.isCancelled {
                write("\r\(frames[index % frames.count]) \(label)...")
                index += 1
                try? await Task.sleep(for: .milliseconds(100))
            }
        }

        do {
            let result = try await operation()
            task.cancel()
            await task.value
            clearInteractiveLine()
            return result
        } catch {
            task.cancel()
            await task.value
            clearInteractiveLine()
            throw error
        }
    }

    private static func clearInteractiveLine() {
        write("\r\u{001B}[2K")
    }

    private static func write(_ value: String) {
        FileHandle.standardError.write(Data(value.utf8))
    }
}

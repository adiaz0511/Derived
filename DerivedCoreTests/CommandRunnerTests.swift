import Foundation
import Testing
@testable import DerivedCore

struct CommandRunnerTests {
    @Test func drainsLargeStandardOutputAndStandardErrorWhileProcessRuns() async throws {
        let byteCount = 262_144
        let command = """
        /usr/bin/yes stdout | /usr/bin/head -c \(byteCount)
        /usr/bin/yes stderr | /usr/bin/head -c \(byteCount) >&2
        """
        let runner = FoundationCommandRunner(timeout: .seconds(10))

        let result = try await runner.run(executable: "/bin/sh", arguments: ["-c", command])

        #expect(result.succeeded)
        #expect(result.standardOutput.utf8.count == byteCount)
        #expect(result.standardError.utf8.count == byteCount)
        #expect(result.standardOutput.hasPrefix("stdout"))
        #expect(result.standardError.hasPrefix("stderr"))
    }

    @Test func terminatesACommandThatExceedsItsTimeout() async {
        let runner = FoundationCommandRunner(timeout: .milliseconds(100))

        await #expect(throws: CommandRunnerError.timedOut(executable: "/bin/sleep")) {
            try await runner.run(executable: "/bin/sleep", arguments: ["5"])
        }
    }
}

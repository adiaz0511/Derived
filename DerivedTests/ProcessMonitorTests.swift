import Foundation
import Testing
@testable import Derived

struct ProcessMonitorTests {
    @Test func detectsRelatedProcessesWithoutMatchingTheAppItself() async {
        let runner = ProcessListRunner(output: """
        /Applications/Xcode.app/Contents/MacOS/Xcode
        /Applications/Derived.app/Contents/MacOS/Derived
        /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild
        """)

        let processes = await ProcessMonitor(runner: runner).activeRelatedProcesses()

        #expect(processes.contains("Xcode"))
        #expect(processes.contains("xcodebuild"))
        #expect(!processes.contains("Derived"))
    }

    @Test func reportsUnavailableWhenProcessInspectionFails() async {
        let runner = ProcessListRunner(output: "", exitCode: 1)

        let inspection = await ProcessMonitor(runner: runner).inspectRelatedProcesses()

        #expect(inspection == .unavailable)
    }
}

private actor ProcessListRunner: CommandRunning {
    let output: String
    let exitCode: Int32

    init(output: String, exitCode: Int32 = 0) {
        self.output = output
        self.exitCode = exitCode
    }

    func run(executable: String, arguments: [String]) async throws -> CommandResult {
        CommandResult(executable: executable, arguments: arguments, standardOutput: output, standardError: "", exitCode: exitCode)
    }
}

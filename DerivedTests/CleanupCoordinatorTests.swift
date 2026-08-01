import Foundation
import Testing
@testable import Derived

struct CleanupCoordinatorTests {
    private let allowedRoot = URL(filePath: "/tmp/DerivedCoordinatorTests", directoryHint: .isDirectory)

    @Test func validFileSystemItemIsPermanentlyDeletedAndWritesHistory() async {
        let remover = RecordingFileRemover()
        let history = RecordingHistoryStore()
        let coordinator = makeCoordinator(fileRemover: remover, historyStore: history)
        let item = fileItem(path: allowedRoot.appending(path: "DerivedDataItem").path)

        let report = await coordinator.execute(items: [item], pinnedRuntimeIDs: [], highRiskConfirmed: false)

        #expect(report.results.first?.outcome == .removed)
        #expect(await remover.removedPaths == [item.path])
        #expect(await history.reports.count == 1)
    }

    @Test func oneInvalidTargetBlocksEntireBatch() async {
        let remover = RecordingFileRemover()
        let coordinator = makeCoordinator(fileRemover: remover)
        let valid = fileItem(path: allowedRoot.appending(path: "Valid").path)
        let invalid = fileItem(path: "/Users/example/Projects/SourceCode")

        let report = await coordinator.execute(items: [valid, invalid], pinnedRuntimeIDs: [], highRiskConfirmed: false)

        #expect(report.results.allSatisfy { $0.outcome == .blocked })
        #expect(await remover.removedPaths.isEmpty)
    }

    @Test func highRiskItemCannotRunWithoutAdditionalAuthorization() async {
        let runner = RecordingCleanupRunner()
        let coordinator = makeCoordinator(runner: runner)
        let item = runtimeItem(safety: .highRisk)

        let report = await coordinator.execute(items: [item], pinnedRuntimeIDs: [], highRiskConfirmed: false)

        #expect(report.results.first?.outcome == .blocked)
        #expect(await runner.invocations.isEmpty)
    }

    @Test func commandFailureDoesNotStopRemainingItems() async {
        let firstID = "D83DCE7D-8848-4F40-B45A-55A5C2E47D06"
        let secondID = "16BE455A-7C8A-43C4-BB91-BBA89FA5D037"
        let runner = RecordingCleanupRunner(failingIdentifier: firstID)
        let coordinator = makeCoordinator(runner: runner)
        let first = simulatorItem(udid: firstID)
        let second = simulatorItem(udid: secondID)

        let report = await coordinator.execute(items: [first, second], pinnedRuntimeIDs: [], highRiskConfirmed: false)

        #expect(report.results.map(\.outcome) == [.failed, .removed])
        #expect(await runner.invocations.count == 2)
    }

    @Test func activeTargetIsBlockedEvenAfterHighRiskConfirmation() async {
        let runner = RecordingCleanupRunner()
        let coordinator = makeCoordinator(runner: runner)
        let item = activeSimulatorItem()

        let report = await coordinator.execute(items: [item], pinnedRuntimeIDs: [], highRiskConfirmed: true)

        #expect(report.results.first?.outcome == .blocked)
        #expect(await runner.invocations.isEmpty)
    }

    @Test func automationIsBlockedWhileDevelopmentToolsAreActive() async {
        let remover = RecordingFileRemover()
        let coordinator = makeCoordinator(
            fileRemover: remover,
            processMonitor: ProcessMonitor(runner: ActiveProcessRunner())
        )
        let item = fileItem(path: allowedRoot.appending(path: "ActiveBuild").path)

        let report = await coordinator.execute(
            items: [item],
            pinnedRuntimeIDs: [],
            highRiskConfirmed: false,
            blockWhenRelatedProcessesAreActive: true,
            trigger: .automation
        )

        #expect(report.trigger == .automation)
        #expect(report.results.first?.outcome == .blocked)
        #expect(await remover.removedPaths.isEmpty)
    }

    @Test func automationFailsClosedWhenProcessesCannotBeInspected() async {
        let remover = RecordingFileRemover()
        let coordinator = makeCoordinator(
            fileRemover: remover,
            processMonitor: ProcessMonitor(runner: FailedProcessRunner())
        )
        let item = fileItem(path: allowedRoot.appending(path: "UnknownProcessState").path)

        let report = await coordinator.execute(
            items: [item],
            pinnedRuntimeIDs: [],
            highRiskConfirmed: false,
            blockWhenRelatedProcessesAreActive: true,
            trigger: .automation
        )

        #expect(report.results.first?.outcome == .blocked)
        #expect(await remover.removedPaths.isEmpty)
    }

    private func makeCoordinator(
        runner: any CommandRunning = RecordingCleanupRunner(),
        fileRemover: any FileRemoving = RecordingFileRemover(),
        processMonitor: ProcessMonitor? = nil,
        historyStore: any CleanupHistoryStoring = RecordingHistoryStore()
    ) -> CleanupCoordinator {
        CleanupCoordinator(
            validator: PathValidator(allowedRoots: [allowedRoot]),
            runner: runner,
            fileRemover: fileRemover,
            processMonitor: processMonitor ?? ProcessMonitor(runner: EmptyProcessRunner()),
            historyStore: historyStore
        )
    }

    private func fileItem(path: String) -> CleanupItem {
        CleanupItem(
            id: "file:\(path)",
            name: URL(filePath: path).lastPathComponent,
            category: .derivedData,
            byteCount: 1_024,
            path: path,
            modifiedAt: nil,
            safety: .recommended,
            reason: "Test",
            isRecommended: true,
            removalMethod: .fileSystem,
            runtime: nil,
            isActive: false
        )
    }

    private func runtimeItem(safety: SafetyClassification) -> CleanupItem {
        let identifier = "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
        return CleanupItem(
            id: "runtime:\(identifier)",
            name: "iOS 26.5",
            category: .simulatorRuntimes,
            byteCount: 2_048,
            path: "simctl://runtime/\(identifier)",
            modifiedAt: nil,
            safety: safety,
            reason: "Test",
            isRecommended: false,
            removalMethod: .simulatorRuntime(identifier: identifier),
            runtime: RuntimeInformation(
                id: identifier,
                name: "iOS 26.5",
                platform: .iOS,
                version: "26.5",
                buildVersion: nil,
                isPrerelease: false,
                isNewestForPlatform: safety == .highRisk,
                isAvailable: true
            ),
            isActive: false
        )
    }

    private func simulatorItem(udid: String) -> CleanupItem {
        CleanupItem(
            id: "device:\(udid)",
            name: udid,
            category: .unavailableSimulators,
            byteCount: 1_024,
            path: "simctl://device/\(udid)",
            modifiedAt: nil,
            safety: .caution,
            reason: "Test",
            isRecommended: true,
            removalMethod: .simulatorDevice(udid: udid),
            runtime: nil,
            isActive: false
        )
    }

    private func activeSimulatorItem() -> CleanupItem {
        let udid = "4A4729B0-AE7E-4B1C-AE09-40A40D4F45C4"
        return CleanupItem(
            id: "device:\(udid)",
            name: "Booted iPhone",
            category: .redundantSimulators,
            byteCount: 1_024,
            path: "simctl://device/\(udid)",
            modifiedAt: nil,
            safety: .highRisk,
            reason: "Booted",
            isRecommended: false,
            removalMethod: .simulatorDevice(udid: udid),
            runtime: nil,
            isActive: true
        )
    }
}

private actor RecordingFileRemover: FileRemoving {
    var removedPaths: [String] = []

    func removeItem(at url: URL) {
        removedPaths.append(url.path)
    }
}

private actor RecordingCleanupRunner: CommandRunning {
    let failingIdentifier: String?
    var invocations: [[String]] = []

    init(failingIdentifier: String? = nil) {
        self.failingIdentifier = failingIdentifier
    }

    func run(executable: String, arguments: [String]) throws -> CommandResult {
        invocations.append(arguments)
        let shouldFail = failingIdentifier.map { arguments.contains($0) } == true
        return CommandResult(
            executable: executable,
            arguments: arguments,
            standardOutput: shouldFail ? "" : "Removed",
            standardError: shouldFail ? "simctl failure" : "",
            exitCode: shouldFail ? 1 : 0
        )
    }
}

private actor EmptyProcessRunner: CommandRunning {
    func run(executable: String, arguments: [String]) throws -> CommandResult {
        CommandResult(
            executable: executable,
            arguments: arguments,
            standardOutput: "",
            standardError: "",
            exitCode: 0
        )
    }
}

private actor ActiveProcessRunner: CommandRunning {
    func run(executable: String, arguments: [String]) throws -> CommandResult {
        CommandResult(
            executable: executable,
            arguments: arguments,
            standardOutput: "/Applications/Xcode.app/Contents/MacOS/Xcode",
            standardError: "",
            exitCode: 0
        )
    }
}

private actor FailedProcessRunner: CommandRunning {
    func run(executable: String, arguments: [String]) throws -> CommandResult {
        CommandResult(
            executable: executable,
            arguments: arguments,
            standardOutput: "",
            standardError: "ps failed",
            exitCode: 1
        )
    }
}

private actor RecordingHistoryStore: CleanupHistoryStoring {
    var reports: [CleanupReport] = []

    func append(_ report: CleanupReport) {
        reports.append(report)
    }
}

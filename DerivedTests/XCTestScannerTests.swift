import Foundation
import Testing
@testable import Derived

struct XCTestScannerTests {
    @Test func logicalCloneSizeIsExcludedFromReclaimableTotal() async throws {
        let temporaryHome = FileManager.default.temporaryDirectory
            .appending(path: "Derived-XCTest-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: temporaryHome) }

        let udid = "01203045-E8D0-4F31-98F0-16BA8E684C00"
        let deviceDirectory = temporaryHome
            .appending(path: "Library/Developer/XCTestDevices/\(udid)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: deviceDirectory, withIntermediateDirectories: true)
        try makePlist(
            name: "Clone 2 of iPhone 17 Pro Max",
            udid: udid,
            isDeleted: false,
            isEphemeral: false
        ).write(to: deviceDirectory.appending(path: "device.plist"))

        let runner = XCTestCommandRunner(output: """
        {
          "devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
              {
                "udid": "\(udid)",
                "name": "Clone 2 of iPhone 17 Pro Max",
                "state": "Shutdown",
                "dataPathSize": 4294967296
              }
            ]
          }
        }
        """)

        let result = await XCTestScanner(runner: runner, homeDirectory: temporaryHome).scan()
        let item = try #require(result.items.first)
        let report = ScanReport(scannedAt: .now, items: [item], activeProcesses: [], warnings: result.warnings)

        #expect(item.byteCount == 4_294_967_296)
        #expect(item.sizeClassification == .apfsCloneLogical)
        #expect(item.verifiedReclaimableBytes == 0)
        #expect(report.discoveredBytes == 0)
        #expect(!item.isRecommended)
        #expect(result.warnings.isEmpty)
    }

    @Test func deletedCloneIsRecommendedWithoutRecursiveTraversal() async throws {
        let temporaryHome = FileManager.default.temporaryDirectory
            .appending(path: "Derived-XCTest-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: temporaryHome) }

        let udid = "005575E5-D4E6-4F65-AA2F-D5C290F6D7E2"
        let deviceDirectory = temporaryHome
            .appending(path: "Library/Developer/XCTestDevices/\(udid)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: deviceDirectory, withIntermediateDirectories: true)
        try makePlist(
            name: "Deleted Test Clone",
            udid: udid,
            isDeleted: true,
            isEphemeral: true
        ).write(to: deviceDirectory.appending(path: "device.plist"))

        let runner = XCTestCommandRunner(output: "{\"devices\":{}}")
        let result = await XCTestScanner(runner: runner, homeDirectory: temporaryHome).scan()
        let item = try #require(result.items.first)

        #expect(item.isRecommended)
        #expect(item.sizeClassification == .verified)
        #expect(item.reason.localizedStandardContains("deleted"))
    }

    private func makePlist(
        name: String,
        udid: String,
        isDeleted: Bool,
        isEphemeral: Bool
    ) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: [
                "name": name,
                "UDID": udid,
                "isDeleted": isDeleted,
                "isEphemeral": isEphemeral,
                "state": 1
            ],
            format: .binary,
            options: 0
        )
    }
}

private actor XCTestCommandRunner: CommandRunning {
    let output: String

    init(output: String) {
        self.output = output
    }

    func run(executable: String, arguments: [String]) async throws -> CommandResult {
        CommandResult(
            executable: executable,
            arguments: arguments,
            standardOutput: output,
            standardError: "",
            exitCode: 0
        )
    }
}

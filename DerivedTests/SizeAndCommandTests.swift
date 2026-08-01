import Foundation
import Testing
@testable import Derived

struct SizeAndCommandTests {
    @Test func reportTotalsRecommendedItemsSeparately() {
        let recommended = fixture(id: "recommended", bytes: 4_000, recommended: true)
        let optional = fixture(id: "optional", bytes: 6_000, recommended: false)
        let report = ScanReport(scannedAt: .now, items: [recommended, optional], activeProcesses: [], warnings: [])

        #expect(report.discoveredBytes == 10_000)
        #expect(report.recommendedBytes == 4_000)
    }

    @Test func diskStorageCalculatesUsedCapacity() {
        let snapshot = DiskStorageSnapshot(totalBytes: 1_000, availableBytes: 250)

        #expect(snapshot.usedBytes == 750)
        #expect(snapshot.usedFraction == 0.75)
    }

    @Test func constructsSupportedSimulatorCommands() {
        let udid = "D83DCE7D-8848-4F40-B45A-55A5C2E47D06"
        let item = CleanupItem(
            id: "device:\(udid)",
            name: "iPhone",
            category: .unavailableSimulators,
            byteCount: 0,
            path: "simctl://device/\(udid)",
            modifiedAt: nil,
            safety: .caution,
            reason: "Unavailable",
            isRecommended: true,
            removalMethod: .simulatorDevice(udid: udid),
            runtime: nil,
            isActive: false
        )

        let command = CleanupCommandBuilder().command(for: item)

        #expect(command?.executable == "/usr/bin/xcrun")
        #expect(command?.arguments == ["simctl", "delete", udid])
    }

    @Test func constructsSupportedRuntimeDeletionCommand() {
        let identifier = "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
        let item = CleanupItem(
            id: "runtime:\(identifier)",
            name: "iOS 26.5",
            category: .simulatorRuntimes,
            byteCount: 0,
            path: "simctl://runtime/\(identifier)",
            modifiedAt: nil,
            safety: .caution,
            reason: "Installed runtime",
            isRecommended: false,
            removalMethod: .simulatorRuntime(identifier: identifier),
            runtime: nil,
            isActive: false
        )

        let command = CleanupCommandBuilder().command(for: item)

        #expect(command?.executable == "/usr/bin/xcrun")
        #expect(command?.arguments == ["simctl", "runtime", "delete", identifier])
    }

    private func fixture(id: String, bytes: Int64, recommended: Bool) -> CleanupItem {
        CleanupItem(
            id: id,
            name: id,
            category: .derivedData,
            byteCount: bytes,
            path: "/tmp/DerivedData/\(id)",
            modifiedAt: nil,
            safety: .recommended,
            reason: "Test",
            isRecommended: recommended,
            removalMethod: .fileSystem,
            runtime: nil,
            isActive: false
        )
    }
}

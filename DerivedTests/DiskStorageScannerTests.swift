import Foundation
import Testing
@testable import Derived

struct DiskStorageScannerTests {
    @Test func returnsCurrentFileSystemCapacity() async throws {
        let directory = FileManager.default.temporaryDirectory
        let scanner = DiskStorageScanner(volumeURL: directory)
        let expected = try directory.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ])

        let snapshot = await scanner.snapshot()

        #expect(snapshot?.totalBytes == expected.volumeTotalCapacity.map(Int64.init))
        #expect(snapshot?.availableBytes == expected.volumeAvailableCapacityForImportantUsage)
        #expect(snapshot?.availableBytes ?? 0 > 0)
        #expect((snapshot?.availableBytes ?? 1) <= (snapshot?.totalBytes ?? 0))
    }
}

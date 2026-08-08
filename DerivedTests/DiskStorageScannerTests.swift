import Foundation
import Testing
@testable import Derived

struct DiskStorageScannerTests {
    @Test func returnsCurrentFileSystemCapacity() async throws {
        let directory = FileManager.default.temporaryDirectory
        let scanner = DiskStorageScanner(volumeURL: directory)
        let expected = try FileManager.default.attributesOfFileSystem(forPath: directory.path)

        let snapshot = await scanner.snapshot()

        #expect(snapshot?.totalBytes == (expected[.systemSize] as? NSNumber)?.int64Value)
        #expect(snapshot?.availableBytes ?? 0 > 0)
        #expect((snapshot?.availableBytes ?? 1) <= (snapshot?.totalBytes ?? 0))
    }
}

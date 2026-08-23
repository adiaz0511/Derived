import Foundation
import Testing
@testable import Derived

struct DiskStorageScannerTests {
    @Test func returnsCurrentFileSystemCapacity() async throws {
        let directory = FileManager.default.temporaryDirectory
        let scanner = DiskStorageScanner(volumeURL: directory)
        let expected = try directory.resourceValues(forKeys: [
            .volumeTotalCapacityKey
        ])

        let snapshot = await scanner.snapshot()

        #expect(snapshot?.totalBytes == expected.volumeTotalCapacity.map(Int64.init))
        #expect(snapshot?.availableBytes ?? 0 > 0)
        #expect((snapshot?.availableBytes ?? 1) <= (snapshot?.totalBytes ?? 0))
    }

    @Test func refreshesCapacityBetweenSnapshots() async throws {
        let directory = FileManager.default.temporaryDirectory
        let scanner = DiskStorageScanner(volumeURL: directory)
        let fileURL = directory.appending(path: "derived-storage-test-\(UUID().uuidString).bin")
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let before = try #require(await scanner.snapshot())

        let handle = try FileHandle(forWritingTo: fileURL)
        let block = Data(repeating: 0x5A, count: 4 * 1_024 * 1_024)
        for _ in 0..<16 {
            try handle.write(contentsOf: block)
        }
        try handle.synchronize()
        try handle.close()

        let after = try #require(await scanner.snapshot())

        #expect(after.availableBytes < before.availableBytes)
    }
}

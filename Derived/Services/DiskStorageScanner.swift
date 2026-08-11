import Foundation

actor DiskStorageScanner {
    private let volumeURL: URL

    init(volumeURL: URL = .homeDirectory) {
        self.volumeURL = volumeURL
    }

    func snapshot() -> DiskStorageSnapshot? {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]
        guard let values = try? volumeURL.resourceValues(forKeys: keys),
              let totalCapacity = values.volumeTotalCapacity else {
            return nil
        }
        let availableCapacity = values.volumeAvailableCapacityForImportantUsage
            ?? values.volumeAvailableCapacity.map(Int64.init)
        guard let availableCapacity else { return nil }

        return DiskStorageSnapshot(
            totalBytes: Int64(totalCapacity),
            availableBytes: availableCapacity
        )
    }
}

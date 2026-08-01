import Foundation

actor DiskStorageScanner {
    private let volumeURL: URL

    init(volumeURL: URL = .homeDirectory) {
        self.volumeURL = volumeURL
    }

    func snapshot() -> DiskStorageSnapshot? {
        guard let values = try? volumeURL.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]), let totalCapacity = values.volumeTotalCapacity else {
            return nil
        }

        let availableCapacity = values.volumeAvailableCapacityForImportantUsage
            ?? values.volumeAvailableCapacity.map(Int64.init)
            ?? 0
        return DiskStorageSnapshot(
            totalBytes: Int64(totalCapacity),
            availableBytes: availableCapacity
        )
    }
}

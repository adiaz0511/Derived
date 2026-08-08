import Foundation

actor DiskStorageScanner {
    private let volumeURL: URL
    private let fileManager: FileManager

    init(
        volumeURL: URL = .homeDirectory,
        fileManager: FileManager = .default
    ) {
        self.volumeURL = volumeURL
        self.fileManager = fileManager
    }

    func snapshot() -> DiskStorageSnapshot? {
        guard let attributes = try? fileManager.attributesOfFileSystem(forPath: volumeURL.path),
              let totalCapacity = (attributes[.systemSize] as? NSNumber)?.int64Value,
              let availableCapacity = (attributes[.systemFreeSize] as? NSNumber)?.int64Value else {
            return nil
        }

        return DiskStorageSnapshot(
            totalBytes: totalCapacity,
            availableBytes: availableCapacity
        )
    }
}

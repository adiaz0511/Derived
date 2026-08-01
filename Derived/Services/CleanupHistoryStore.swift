import Foundation

nonisolated protocol CleanupHistoryStoring: Sendable {
    func append(_ report: CleanupReport) async throws
}

actor CleanupHistoryStore: CleanupHistoryStoring {
    let fileURL: URL
    private let fileManager: FileManager

    init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let destination = URL.applicationSupportDirectory
                .appending(path: "Derived", directoryHint: .isDirectory)
                .appending(path: "cleanup-history.jsonl")
            self.fileURL = destination
            migrateLegacyHistoryIfNeeded(to: destination, fileManager: fileManager)
        }
    }

    func append(_ report: CleanupReport) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var data = try encoder.encode(report)
        data.append(0x0A)

        if fileManager.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } else {
            try data.write(to: fileURL, options: .atomic)
        }
    }

    private nonisolated func migrateLegacyHistoryIfNeeded(
        to destination: URL,
        fileManager: FileManager
    ) {
        guard !fileManager.fileExists(atPath: destination.path) else { return }

        let legacyURL = URL.applicationSupportDirectory
            .appending(path: "XcodeClean", directoryHint: .isDirectory)
            .appending(path: "cleanup-history.jsonl")
        guard fileManager.fileExists(atPath: legacyURL.path) else { return }

        try? fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? fileManager.moveItem(at: legacyURL, to: destination)
    }
}

import Foundation

nonisolated protocol CleanupHistoryStoring: Sendable {
    func append(_ report: CleanupReport) async throws
}

actor CleanupHistoryStore: CleanupHistoryStoring {
    static let defaultMaximumBytes = 1_048_576
    static let defaultRetainedBytes = 786_432

    let fileURL: URL
    private let fileManager: FileManager
    private let maximumBytes: Int
    private let retainedBytes: Int

    init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        maximumBytes: Int = CleanupHistoryStore.defaultMaximumBytes,
        retainedBytes: Int = CleanupHistoryStore.defaultRetainedBytes
    ) {
        precondition(maximumBytes > 0)
        precondition(retainedBytes > 0 && retainedBytes < maximumBytes)
        self.fileManager = fileManager
        self.maximumBytes = maximumBytes
        self.retainedBytes = retainedBytes
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

        try compactIfNeeded()
    }

    private func compactIfNeeded() throws {
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        guard let fileSize = attributes[.size] as? NSNumber,
              fileSize.intValue > maximumBytes else { return }

        let history = try Data(contentsOf: fileURL)
        let retainedStart = max(0, history.count - retainedBytes)
        let retainedSlice = history[retainedStart...]
        let alignedStart = retainedSlice.firstIndex(of: 0x0A).map { history.index(after: $0) }
            ?? history.startIndex
        let compacted = history[alignedStart...]
        try Data(compacted).write(to: fileURL, options: .atomic)
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

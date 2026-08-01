import Foundation
import Testing
@testable import Derived

struct CleanupHistoryStoreTests {
    @Test func appendsOneJSONRecordPerCleanup() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Derived-History-\(UUID().uuidString)", directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "history.jsonl")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CleanupHistoryStore(fileURL: fileURL)
        let report = CleanupReport(
            id: UUID(),
            trigger: .manual,
            startedAt: .now,
            completedAt: .now,
            results: [],
            activeProcesses: [],
            historyError: nil
        )

        try await store.append(report)
        try await store.append(report)

        let lines = try String(contentsOf: fileURL, encoding: .utf8)
            .split(separator: "\n")
        #expect(lines.count == 2)
    }
}

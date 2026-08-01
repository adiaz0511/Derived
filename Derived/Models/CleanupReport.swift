import Foundation

nonisolated struct CleanupReport: Codable, Identifiable, Sendable {
    let id: UUID
    let trigger: CleanupTrigger
    let startedAt: Date
    let completedAt: Date
    let results: [CleanupItemResult]
    let activeProcesses: [String]
    var historyError: String?

    var successfulResults: [CleanupItemResult] {
        results.filter(\.succeeded)
    }

    var permanentlyRemovedBytes: Int64 {
        results
            .filter { $0.outcome == .removed }
            .reduce(0) { $0 + $1.byteCount }
    }

    var failureCount: Int {
        results.count { $0.outcome == .failed }
    }

    var blockedCount: Int {
        results.count { $0.outcome == .blocked }
    }
}

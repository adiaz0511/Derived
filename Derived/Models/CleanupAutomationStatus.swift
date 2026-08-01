import Foundation

nonisolated enum CleanupAutomationStatus: Equatable, Sendable {
    case deferred(activeProcesses: [String])
    case completed(Date)
    case failed(String)
}

import Foundation

nonisolated enum CleanupOutcome: String, Codable, Sendable {
    case removed
    case failed
    case blocked
}

import Foundation

nonisolated enum CleanupTrigger: String, Codable, Sendable {
    case manual
    case automation
}

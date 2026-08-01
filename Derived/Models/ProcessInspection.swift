import Foundation

nonisolated enum ProcessInspection: Equatable, Sendable {
    case available(activeProcesses: [String])
    case unavailable
}

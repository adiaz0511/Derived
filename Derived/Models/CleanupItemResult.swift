import Foundation

nonisolated struct CleanupItemResult: Codable, Identifiable, Sendable {
    let itemID: String
    let name: String
    let category: CleanupCategory
    let path: String
    let byteCount: Int64
    let logicalByteCount: Int64?
    let outcome: CleanupOutcome
    let operation: String
    let message: String

    var id: String { itemID }

    var succeeded: Bool {
        outcome == .removed
    }
}

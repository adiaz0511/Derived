import Foundation

nonisolated public struct AgentCleanupSelection: Codable, Sendable {
    public let itemIDs: [String]
    public let categories: [AgentCategory]

    public init(itemIDs: [String] = [], categories: [AgentCategory] = []) {
        self.itemIDs = itemIDs
        self.categories = categories
    }
}

nonisolated public struct AgentCleanupPlan: Codable, Sendable {
    public let schemaVersion: Int
    public let planID: UUID
    public let scanID: UUID
    public let createdAt: Date
    public let expiresAt: Date
    public let itemCount: Int
    public let verifiedReclaimableBytes: Int64
    public let logicalBytes: Int64
    public let categories: [AgentCategory]
    public let requiresAdditionalConfirmation: Bool
    public let confirmationPhrase: String
}

nonisolated public struct AgentCleanupItemResult: Codable, Identifiable, Sendable {
    public let itemID: String
    public let name: String
    public let category: AgentCategory
    public let byteCount: Int64
    public let outcome: String
    public let message: String

    public var id: String { itemID }
}

nonisolated public struct AgentCleanupResult: Codable, Sendable {
    public let schemaVersion: Int
    public let planID: UUID
    public let completedAt: Date
    public let permanentlyRemovedBytes: Int64
    public let failureCount: Int
    public let blockedCount: Int
    public let items: [AgentCleanupItemResult]
    public let historyError: String?
}

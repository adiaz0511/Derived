import Foundation

nonisolated public struct AgentCategorySummary: Codable, Identifiable, Sendable {
    public let category: AgentCategory
    public let itemCount: Int
    public let verifiedReclaimableBytes: Int64
    public let logicalBytes: Int64
    public let recommendedItemCount: Int

    public var id: AgentCategory { category }
}

nonisolated public struct AgentScan: Codable, Sendable {
    public let schemaVersion: Int
    public let scanID: UUID
    public let scannedAt: Date
    public let expiresAt: Date
    public let categories: [AgentCategorySummary]
    public let activeProcesses: [String]
    public let warnings: [String]
}

nonisolated public struct AgentCandidatePage: Codable, Sendable {
    public let schemaVersion: Int
    public let scanID: UUID
    public let category: AgentCategory
    public let candidates: [AgentCandidate]
    public let offset: Int
    public let limit: Int
    public let totalCount: Int
    public let nextOffset: Int?
}

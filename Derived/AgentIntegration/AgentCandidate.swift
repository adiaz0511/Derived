import Foundation

nonisolated public struct AgentCandidate: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: AgentCategory
    public let byteCount: Int64
    public let verifiedReclaimableBytes: Int64
    public let logicalSizeOnly: Bool
    public let path: String
    public let modifiedAt: Date?
    public let reason: String
    public let isRecommended: Bool
    public let isActive: Bool
    public let requiresAdditionalConfirmation: Bool

    init(item: CleanupItem, pinnedRuntimeIDs: Set<String>) {
        id = item.id
        name = item.name
        category = AgentCategory(item.category)
        byteCount = item.byteCount
        verifiedReclaimableBytes = item.verifiedReclaimableBytes
        logicalSizeOnly = item.sizeClassification == .apfsCloneLogical
        path = item.path
        modifiedAt = item.modifiedAt
        reason = item.reason
        isRecommended = item.isRecommended
        isActive = item.isActive
        let isPinned = item.runtime.map { pinnedRuntimeIDs.contains($0.id) } == true
        requiresAdditionalConfirmation = item.safety == .highRisk
            || isPinned
            || item.runtime?.isNewestForPlatform == true
    }
}

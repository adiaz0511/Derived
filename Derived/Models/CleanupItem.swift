import Foundation

nonisolated struct CleanupItem: Identifiable, Hashable, Sendable {
    enum RemovalMethod: Hashable, Sendable {
        case fileSystem
        case simulatorDevice(udid: String)
        case simulatorRuntime(identifier: String)
    }

    let id: String
    let name: String
    let category: CleanupCategory
    let byteCount: Int64
    let path: String
    let modifiedAt: Date?
    let safety: SafetyClassification
    let reason: String
    let isRecommended: Bool
    let removalMethod: RemovalMethod
    let runtime: RuntimeInformation?
    let isActive: Bool
    var sizeClassification: CleanupSizeClassification = .verified

    var ageInDays: Int? {
        guard let modifiedAt else { return nil }
        return Calendar.current.dateComponents([.day], from: modifiedAt, to: .now).day
    }

    var verifiedReclaimableBytes: Int64 {
        sizeClassification == .verified ? byteCount : 0
    }
}

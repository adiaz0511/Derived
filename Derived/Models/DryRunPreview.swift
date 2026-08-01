import Foundation

nonisolated struct DryRunPreview: Identifiable, Sendable {
    let id = UUID()
    let generatedAt = Date.now
    let items: [CleanupItem]
    let validations: [String: PathValidationResult]

    var byteCount: Int64 {
        items.reduce(0) { $0 + $1.verifiedReclaimableBytes }
    }

    var hasInvalidTargets: Bool {
        validations.values.contains { !$0.isValid }
    }

    var containsLogicalCloneSizes: Bool {
        items.contains { $0.sizeClassification == .apfsCloneLogical }
    }
}

import Foundation

nonisolated struct CleanupPreflight: Sendable {
    let validations: [String: PathValidationResult]
    let activeProcesses: [String]
    let highRiskItemIDs: Set<String>

    var hasInvalidTargets: Bool {
        validations.values.contains { !$0.isValid }
    }

    var requiresHighRiskConfirmation: Bool {
        !highRiskItemIDs.isEmpty
    }
}

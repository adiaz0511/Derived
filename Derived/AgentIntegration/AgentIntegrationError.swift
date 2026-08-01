import Foundation

nonisolated public enum AgentIntegrationError: LocalizedError, Sendable {
    case invalidCategory(String)
    case invalidConfirmation
    case invalidLimit
    case missingCandidates([String])
    case noCandidatesSelected
    case planExpired
    case planNotFound
    case scanExpired
    case scanNotFound
    case staleCandidates([String])

    public var errorDescription: String? {
        switch self {
        case .invalidCategory(let value):
            "Unknown cleanup category: \(value)."
        case .invalidConfirmation:
            "The confirmation phrase does not match the cleanup plan."
        case .invalidLimit:
            "The page limit must be between 1 and 50."
        case .missingCandidates(let identifiers):
            "The scan does not contain these candidate identifiers: \(identifiers.joined(separator: ", "))."
        case .noCandidatesSelected:
            "The cleanup selection did not match any candidates."
        case .planExpired:
            "The cleanup plan expired. Prepare a new plan from a fresh scan."
        case .planNotFound:
            "The cleanup plan was not found. Prepare a new plan."
        case .scanExpired:
            "The scan expired. Run a new scan."
        case .scanNotFound:
            "The scan was not found. Run a new scan."
        case .staleCandidates(let identifiers):
            "The cleanup candidates changed after the plan was prepared: \(identifiers.joined(separator: ", "))."
        }
    }
}

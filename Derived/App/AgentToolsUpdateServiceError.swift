import Foundation

enum AgentToolsUpdateServiceError: LocalizedError {
    case missingPayload
    case unsupportedInstallation
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingPayload:
            "The bundled Agent Tools update could not be found."
        case .unsupportedInstallation:
            "This Agent Tools installation must be updated by its package manager."
        case .commandFailed(let output):
            output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "The update did not complete. Your existing installation was not changed."
                : output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

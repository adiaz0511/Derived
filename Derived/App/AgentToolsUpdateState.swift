import Foundation

enum AgentToolsUpdateState: Equatable {
    case idle
    case checking
    case available(AgentToolsUpdateAvailability)
    case updating(AgentToolsUpdateAvailability)
    case completed(AgentToolsUpdateResult)
    case failed(AgentToolsUpdateAvailability, String)
}

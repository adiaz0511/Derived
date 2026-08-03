import Foundation

struct AgentToolsUpdateAvailability: Equatable, Sendable {
    let installationKind: AgentToolsInstallationKind
    let installedVersion: AgentToolsVersion
    let availableVersion: AgentToolsVersion
    let payloadRoot: URL
    let installedClients: [String]
}

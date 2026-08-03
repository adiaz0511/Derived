import Foundation

nonisolated struct InstalledAgentTools: Sendable {
    let kind: AgentToolsInstallationKind
    let version: AgentToolsVersion
}

import Foundation

nonisolated public struct AgentToolsUpdateManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let version: String
    public let releaseURL: URL

    public init(schemaVersion: Int, version: String, releaseURL: URL) {
        self.schemaVersion = schemaVersion
        self.version = version
        self.releaseURL = releaseURL
    }

    public var parsedVersion: AgentToolsVersion? {
        AgentToolsVersion(version)
    }
}

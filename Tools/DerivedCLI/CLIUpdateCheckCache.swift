import DerivedCore
import Foundation

struct CLIUpdateCheckCache: Codable, Equatable {
    let checkedAt: Date
    let manifest: AgentToolsUpdateManifest?
}

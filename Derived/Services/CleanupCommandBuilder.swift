import Foundation

nonisolated struct CleanupCommand: Equatable, Sendable {
    let executable: String
    let arguments: [String]
}

nonisolated struct CleanupCommandBuilder: Sendable {
    func command(for item: CleanupItem) -> CleanupCommand? {
        switch item.removalMethod {
        case .fileSystem:
            nil
        case .simulatorDevice(let udid):
            CleanupCommand(executable: "/usr/bin/xcrun", arguments: ["simctl", "delete", udid])
        case .simulatorRuntime(let identifier):
            CleanupCommand(executable: "/usr/bin/xcrun", arguments: ["simctl", "runtime", "delete", identifier])
        }
    }
}

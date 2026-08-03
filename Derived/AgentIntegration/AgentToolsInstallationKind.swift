import Foundation

nonisolated public enum AgentToolsInstallationKind: String, Codable, Sendable {
    case dmg
    case homebrew
    case manual

    public static func classify(executableURL: URL, homeDirectory: URL) -> Self {
        let executablePath = executableURL.resolvingSymlinksInPath().standardizedFileURL.path
        let localBinPath = homeDirectory.appending(path: ".local/bin").standardizedFileURL.path

        if executablePath == localBinPath || executablePath.hasPrefix(localBinPath + "/") {
            return .dmg
        }
        if executablePath.contains("/Caskroom/derived-tools/") {
            return .homebrew
        }
        return .manual
    }
}

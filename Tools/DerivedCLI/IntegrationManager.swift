import DerivedCore
import Foundation

enum IntegrationManagerError: LocalizedError {
    case bundledSkillMissing
    case mcpServerMissing
    case noClientsDetected
    case commandFailed(String)
    case unsupportedUpdate

    var errorDescription: String? {
        switch self {
        case .bundledSkillMissing:
            "The derived-cleanup skill was not found beside this Homebrew installation. Reinstall derived-tools."
        case .mcpServerMissing:
            "The derived-mcp executable was not found beside the Derived CLI. Reinstall derived-tools."
        case .noClientsDetected:
            "No supported client was detected. Use --client codex, claude, or cursor."
        case .commandFailed(let message):
            message
        case .unsupportedUpdate:
            "This installation is not managed by Homebrew. Download the latest Derived release to update it."
        }
    }
}

struct IntegrationManager {
    private let fileManager: FileManager
    private let homeDirectory: URL
    private let invokedCLIURL: URL
    private let environment: [String: String]

    init(
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil,
        invokedCLIURL: URL = URL(fileURLWithPath: CommandLine.arguments[0]),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        self.invokedCLIURL = invokedCLIURL
        self.environment = environment
    }

    func run(_ command: IntegrationCommand) throws -> String {
        switch command {
        case .install(let requestedClient):
            return try install(requestedClient: requestedClient)
        case .status:
            return status()
        case .update:
            return try update()
        }
    }

    private func install(requestedClient: IntegrationClient?) throws -> String {
        let clients = try clientsToInstall(requestedClient)
        let skillSource = try bundledSkillURL()
        let mcpExecutable = try mcpExecutableURL()
        var installed: [String] = []

        for client in clients {
            try registerMCP(executable: mcpExecutable, for: client)
            try installSkill(from: skillSource, for: client)
            installed.append(client.displayName)
        }

        return "Installed Derived integrations for: \(installed.joined(separator: ", ")). Restart these clients before using Derived."
    }

    private func update() throws -> String {
        guard let brew = executable(named: "brew"), isHomebrewInstallation else {
            throw IntegrationManagerError.unsupportedUpdate
        }

        try runProcess(brew, arguments: ["upgrade", "--cask", "derived-tools"], failureMessage: "Homebrew could not update derived-tools.")
        let result = try install(requestedClient: nil)
        return "Derived Agent Tools are current. \(result)"
    }

    private func status() -> String {
        let mcpPath = (try? mcpExecutableURL().path) ?? "not found"
        var lines = [
            "Derived Agent Tools \(DerivedAgentVersion.current)",
            "MCP executable: \(mcpPath)",
            ""
        ]

        for client in IntegrationClient.allCases {
            let skillInstalled = fileManager.fileExists(atPath: skillDestination(for: client).path)
            lines.append("\(client.displayName): skill \(skillInstalled ? "installed" : "not installed")")
        }
        return lines.joined(separator: "\n")
    }

    private func clientsToInstall(_ requestedClient: IntegrationClient?) throws -> [IntegrationClient] {
        if let requestedClient {
            return [requestedClient]
        }
        let detected = IntegrationClient.allCases.filter(isDetected)
        guard !detected.isEmpty else {
            throw IntegrationManagerError.noClientsDetected
        }
        return detected
    }

    private func isDetected(_ client: IntegrationClient) -> Bool {
        switch client {
        case .codex:
            executable(named: "codex") != nil
        case .claude:
            executable(named: "claude") != nil
        case .cursor:
            fileManager.fileExists(atPath: homeDirectory.appending(path: ".cursor").path)
                || fileManager.fileExists(atPath: "/Applications/Cursor.app")
        }
    }

    private func installSkill(from source: URL, for client: IntegrationClient) throws {
        let destination = skillDestination(for: client)
        let skillsDirectory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: skillsDirectory, withIntermediateDirectories: true)

        let staging = skillsDirectory.appending(path: ".derived-cleanup-\(UUID().uuidString)")
        let backup = skillsDirectory.appending(path: ".derived-cleanup-backup-\(UUID().uuidString)")
        defer {
            try? fileManager.removeItem(at: staging)
            try? fileManager.removeItem(at: backup)
        }
        try fileManager.copyItem(at: source, to: staging)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.moveItem(at: destination, to: backup)
        }
        do {
            try fileManager.moveItem(at: staging, to: destination)
        } catch {
            if fileManager.fileExists(atPath: backup.path) {
                try? fileManager.moveItem(at: backup, to: destination)
            }
            throw error
        }
    }

    private func registerMCP(executable: URL, for client: IntegrationClient) throws {
        switch client {
        case .codex:
            guard let codex = self.executable(named: "codex") else {
                throw IntegrationManagerError.commandFailed("Codex was selected, but the codex command is unavailable.")
            }
            try? runProcess(
                codex,
                arguments: ["mcp", "remove", "derived"],
                failureMessage: "",
                suppressOutput: true
            )
            try runProcess(
                codex,
                arguments: ["mcp", "add", "derived", "--", executable.path],
                failureMessage: "Codex could not register the Derived MCP server."
            )
        case .claude:
            guard let claude = self.executable(named: "claude") else {
                throw IntegrationManagerError.commandFailed("Claude Code was selected, but the claude command is unavailable.")
            }
            try? runProcess(
                claude,
                arguments: ["mcp", "remove", "derived", "--scope", "user"],
                failureMessage: "",
                suppressOutput: true
            )
            try runProcess(
                claude,
                arguments: ["mcp", "add", "derived", "--scope", "user", "--", executable.path],
                failureMessage: "Claude Code could not register the Derived MCP server."
            )
        case .cursor:
            try registerCursorMCP(executable: executable)
        }
    }

    private func registerCursorMCP(executable: URL) throws {
        let configURL = homeDirectory.appending(path: ".cursor/mcp.json")
        try fileManager.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        var root: [String: Any] = [:]
        if fileManager.fileExists(atPath: configURL.path) {
            let data = try Data(contentsOf: configURL)
            guard let existing = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw IntegrationManagerError.commandFailed("Cursor's MCP configuration is not a JSON object and was not changed.")
            }
            root = existing
        }
        if root["mcpServers"] != nil, root["mcpServers"] as? [String: Any] == nil {
            throw IntegrationManagerError.commandFailed("Cursor's mcpServers value is not a JSON object and was not changed.")
        }
        var servers = root["mcpServers"] as? [String: Any] ?? [:]
        servers["derived"] = ["command": executable.path, "args": []]
        root["mcpServers"] = servers

        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: configURL, options: .atomic)
    }

    private func bundledSkillURL() throws -> URL {
        let executableURL = resolvedCLIURL()
        var candidates = [
            executableURL.deletingLastPathComponent().deletingLastPathComponent().appending(path: "Integrations/derived-cleanup"),
            executableURL.deletingLastPathComponent().appending(path: "../Integrations/derived-cleanup").standardizedFileURL
        ]
        if let sourceDirectory = environment["DERIVED_AGENT_TOOLS_SOURCE_DIR"] {
            candidates.append(URL(fileURLWithPath: sourceDirectory).appending(path: "Integrations/derived-cleanup"))
        }
        guard let result = candidates.first(where: { fileManager.fileExists(atPath: $0.appending(path: "SKILL.md").path) }) else {
            throw IntegrationManagerError.bundledSkillMissing
        }
        return result
    }

    private func mcpExecutableURL() throws -> URL {
        let stableSibling = invokedCLIURL.deletingLastPathComponent().appending(path: "derived-mcp")
        let resolvedSibling = resolvedCLIURL().deletingLastPathComponent().appending(path: "derived-mcp")
        guard let result = [stableSibling, resolvedSibling].first(where: { fileManager.isExecutableFile(atPath: $0.path) }) else {
            throw IntegrationManagerError.mcpServerMissing
        }
        return result.standardizedFileURL
    }

    private func resolvedCLIURL() -> URL {
        let resolvedInvocation = invokedCLIURL.resolvingSymlinksInPath().standardizedFileURL
        if fileManager.isExecutableFile(atPath: resolvedInvocation.path) {
            return resolvedInvocation
        }

        if let executableFromPath = executable(named: invokedCLIURL.lastPathComponent) {
            return executableFromPath.resolvingSymlinksInPath().standardizedFileURL
        }

        return resolvedInvocation
    }

    private var isHomebrewInstallation: Bool {
        resolvedCLIURL().path.contains("/Caskroom/derived-tools/")
    }

    private func skillDestination(for client: IntegrationClient) -> URL {
        let directory = switch client {
        case .codex: ".codex"
        case .claude: ".claude"
        case .cursor: ".cursor"
        }
        return homeDirectory.appending(path: "\(directory)/skills/derived-cleanup")
    }

    private func executable(named name: String) -> URL? {
        let paths = (environment["PATH"] ?? "").split(separator: ":")
        return paths
            .map { URL(fileURLWithPath: String($0)).appending(path: name) }
            .first { fileManager.isExecutableFile(atPath: $0.path) }
    }

    private func runProcess(
        _ executable: URL,
        arguments: [String],
        failureMessage: String,
        suppressOutput: Bool = false
    ) throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = suppressOutput ? FileHandle.nullDevice : FileHandle.standardOutput
        process.standardError = suppressOutput ? FileHandle.nullDevice : FileHandle.standardError
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw IntegrationManagerError.commandFailed(failureMessage)
        }
    }
}

private extension IntegrationClient {
    var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude Code"
        case .cursor: "Cursor"
        }
    }
}

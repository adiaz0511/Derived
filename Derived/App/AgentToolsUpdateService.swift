import Foundation

nonisolated struct AgentToolsUpdateService: Sendable {
    private let homeDirectory: URL
    private let bundleResourceURL: URL?

    init(
        homeDirectory: URL? = nil,
        bundleResourceURL: URL? = Bundle.main.resourceURL
    ) {
        self.homeDirectory = homeDirectory ?? FileManager.default.homeDirectoryForCurrentUser
        self.bundleResourceURL = bundleResourceURL
    }

    func availability() async -> AgentToolsUpdateAvailability? {
        guard let payloadRoot = bundleResourceURL?.appending(path: "AgentTools"),
              let availableVersion = await version(
                  of: payloadRoot.appending(path: "bin/derived")
              ),
              let installation = await installedTools() else {
            return nil
        }

        guard installation.version < availableVersion,
              installation.kind != .manual else {
            return nil
        }

        return AgentToolsUpdateAvailability(
            installationKind: installation.kind,
            installedVersion: installation.version,
            availableVersion: availableVersion,
            payloadRoot: payloadRoot,
            installedClients: installedClients()
        )
    }

    func install(_ availability: AgentToolsUpdateAvailability) async throws -> AgentToolsUpdateResult {
        guard availability.installationKind == .dmg else {
            throw AgentToolsUpdateServiceError.unsupportedInstallation
        }

        let scriptURL = availability.payloadRoot.appending(path: "update-agent-tools.sh")
        guard FileManager.default.isExecutableFile(atPath: scriptURL.path) else {
            throw AgentToolsUpdateServiceError.missingPayload
        }

        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = homeDirectory.path
        environment["DERIVED_AGENT_TOOLS_SOURCE_DIR"] = availability.payloadRoot.path
        let output = try await run(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: [scriptURL.path],
            environment: environment
        )
        return AgentToolsUpdateResult(
            version: availability.availableVersion.description,
            detail: completionDetail(for: availability, output: output)
        )
    }

    private func installedClients() -> [String] {
        [
            ("Codex", ".codex/skills/derived-cleanup/SKILL.md"),
            ("Claude Code", ".claude/skills/derived-cleanup/SKILL.md"),
            ("Cursor", ".cursor/skills/derived-cleanup/SKILL.md")
        ].compactMap { name, path in
            FileManager.default.fileExists(atPath: homeDirectory.appending(path: path).path) ? name : nil
        }
    }

    private func completionDetail(
        for availability: AgentToolsUpdateAvailability,
        output: String
    ) -> String {
        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Version \(availability.availableVersion) is installed."
        }
        guard !availability.installedClients.isEmpty else {
            return "Version \(availability.availableVersion) is installed."
        }
        let clients = availability.installedClients.formatted(.list(type: .and))
        return "Version \(availability.availableVersion) is installed for \(clients). Restart these apps before using Derived."
    }

    private func installedTools() async -> InstalledAgentTools? {
        let localCLI = homeDirectory.appending(path: ".local/bin/derived")
        if let version = await version(of: localCLI) {
            return InstalledAgentTools(kind: .dmg, version: version)
        }

        for stableURL in [
            URL(fileURLWithPath: "/opt/homebrew/bin/derived"),
            URL(fileURLWithPath: "/usr/local/bin/derived")
        ] {
            guard FileManager.default.isExecutableFile(atPath: stableURL.path) else { continue }
            let resolvedURL = stableURL.resolvingSymlinksInPath()
            guard AgentToolsInstallationKind.classify(
                executableURL: resolvedURL,
                homeDirectory: homeDirectory
            ) == .homebrew,
            let version = await version(of: stableURL) else {
                continue
            }
            return InstalledAgentTools(kind: .homebrew, version: version)
        }
        return nil
    }

    private func version(of executableURL: URL) async -> AgentToolsVersion? {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path),
              let output = try? await run(
                  executableURL: executableURL,
                  arguments: ["--version"],
                  environment: ProcessInfo.processInfo.environment
              ),
              output.hasPrefix("derived ") else {
            return nil
        }
        return AgentToolsVersion(output.dropFirst("derived ".count).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            process.executableURL = executableURL
            process.arguments = arguments
            process.environment = environment
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            process.terminationHandler = { completedProcess in
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                if completedProcess.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: AgentToolsUpdateServiceError.commandFailed(output))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

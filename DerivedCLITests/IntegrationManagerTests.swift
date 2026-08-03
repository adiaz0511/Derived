@testable import DerivedCLI
import Foundation
import Testing

struct IntegrationManagerTests {
    @Test
    func installsCursorSkillAndMCPConfigurationFromCaskPayload() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: "derived-integration-test-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        let home = root.appending(path: "home")
        let payload = root.appending(path: "Caskroom/derived-tools/1.0.4/.agent-tools")
        let bin = payload.appending(path: "bin")
        let skill = payload.appending(path: "Integrations/derived-cleanup")
        try fileManager.createDirectory(at: bin, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: skill, withIntermediateDirectories: true)

        let cli = bin.appending(path: "derived")
        let mcp = bin.appending(path: "derived-mcp")
        try Data().write(to: cli)
        try Data().write(to: mcp)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cli.path)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: mcp.path)
        try Data("# Derived skill".utf8).write(to: skill.appending(path: "SKILL.md"))

        let manager = IntegrationManager(
            fileManager: fileManager,
            homeDirectory: home,
            invokedCLIURL: cli,
            environment: [:]
        )

        let output = try manager.run(.install(client: .cursor))

        #expect(output.contains("Cursor"))
        #expect(fileManager.fileExists(atPath: home.appending(path: ".cursor/skills/derived-cleanup/SKILL.md").path))

        let configData = try Data(contentsOf: home.appending(path: ".cursor/mcp.json"))
        let config = try #require(JSONSerialization.jsonObject(with: configData) as? [String: Any])
        let servers = try #require(config["mcpServers"] as? [String: Any])
        let derived = try #require(servers["derived"] as? [String: Any])
        #expect(derived["command"] as? String == mcp.path)
    }

    @Test
    func resolvesCaskPayloadWhenInvokedByBareCommandName() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: "derived-path-test-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        let home = root.appending(path: "home")
        let payload = root.appending(path: "Caskroom/derived-tools/1.0.4/.agent-tools")
        let payloadBin = payload.appending(path: "bin")
        let skill = payload.appending(path: "Integrations/derived-cleanup")
        let linkedBin = root.appending(path: "bin")
        try fileManager.createDirectory(at: payloadBin, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: skill, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: linkedBin, withIntermediateDirectories: true)

        let cli = payloadBin.appending(path: "derived")
        let mcp = payloadBin.appending(path: "derived-mcp")
        try Data().write(to: cli)
        try Data().write(to: mcp)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cli.path)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: mcp.path)
        try Data("# Derived skill".utf8).write(to: skill.appending(path: "SKILL.md"))
        try fileManager.createSymbolicLink(at: linkedBin.appending(path: "derived"), withDestinationURL: cli)
        try fileManager.createSymbolicLink(at: linkedBin.appending(path: "derived-mcp"), withDestinationURL: mcp)

        let manager = IntegrationManager(
            fileManager: fileManager,
            homeDirectory: home,
            invokedCLIURL: root.appending(path: "working-directory/derived"),
            environment: ["PATH": linkedBin.path]
        )

        let output = try manager.run(.install(client: .cursor))

        #expect(output.contains("Cursor"))
        #expect(fileManager.fileExists(atPath: home.appending(path: ".cursor/skills/derived-cleanup/SKILL.md").path))

        let configData = try Data(contentsOf: home.appending(path: ".cursor/mcp.json"))
        let config = try #require(JSONSerialization.jsonObject(with: configData) as? [String: Any])
        let servers = try #require(config["mcpServers"] as? [String: Any])
        let derived = try #require(servers["derived"] as? [String: Any])
        #expect(derived["command"] as? String == mcp.path)
    }

    @Test
    func homebrewUpdateRefreshesIntegrationsWithNewCLI() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: "derived-homebrew-update-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        let caskBin = root.appending(path: "Caskroom/derived-tools/1.0.3/.agent-tools/bin")
        let stableBin = root.appending(path: "bin")
        let logURL = root.appending(path: "commands.log")
        try fileManager.createDirectory(at: caskBin, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: stableBin, withIntermediateDirectories: true)

        let invokedCLI = caskBin.appending(path: "derived")
        try writeExecutable("#!/bin/zsh\n", to: invokedCLI)
        try writeExecutable(
            "#!/bin/zsh\nprint -r -- \"brew $@\" >> \"\(logURL.path)\"\n",
            to: stableBin.appending(path: "brew")
        )
        try writeExecutable(
            "#!/bin/zsh\nprint -r -- \"derived $@\" >> \"\(logURL.path)\"\n",
            to: stableBin.appending(path: "derived")
        )

        let manager = IntegrationManager(
            fileManager: fileManager,
            homeDirectory: root.appending(path: "home"),
            invokedCLIURL: invokedCLI,
            environment: [
                "PATH": stableBin.path
            ]
        )

        let output = try manager.run(.update)
        let commands = try String(contentsOf: logURL, encoding: .utf8)

        #expect(output == "Derived Agent Tools are current.")
        #expect(commands.contains("brew upgrade --cask derived-tools"))
        #expect(commands.contains("derived integrations install"))
    }

    private func writeExecutable(_ contents: String, to url: URL) throws {
        try Data(contents.utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}

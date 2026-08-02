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
        let payload = root.appending(path: "Caskroom/derived-tools/1.0.2/.agent-tools")
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
}

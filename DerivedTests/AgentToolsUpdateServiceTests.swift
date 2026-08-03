@testable import Derived
import Foundation
import Testing

struct AgentToolsUpdateServiceTests {
    @Test
    func detectsAndUpdatesDMGManagedTools() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: "derived-app-update-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }

        let home = root.appending(path: "home")
        let resources = root.appending(path: "Resources")
        let payload = resources.appending(path: "AgentTools")
        let payloadBin = payload.appending(path: "bin")
        let payloadSkill = payload.appending(path: "Integrations/derived-cleanup")
        let installedBin = home.appending(path: ".local/bin")
        let installedSkill = home.appending(path: ".codex/skills/derived-cleanup")
        try fileManager.createDirectory(at: payloadBin, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: payloadSkill, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: installedBin, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: installedSkill, withIntermediateDirectories: true)

        try writeExecutable(version: "1.0.5", to: payloadBin.appending(path: "derived"))
        try writeExecutable(version: "1.0.5", to: payloadBin.appending(path: "derived-mcp"))
        try writeExecutable(version: "1.0.4", to: installedBin.appending(path: "derived"))
        try writeExecutable(version: "1.0.4", to: installedBin.appending(path: "derived-mcp"))
        try Data("new skill".utf8).write(to: payloadSkill.appending(path: "SKILL.md"))
        try Data("old skill".utf8).write(to: installedSkill.appending(path: "SKILL.md"))

        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let updateScript = projectRoot.appending(path: "scripts/update-agent-tools.sh")
        try fileManager.copyItem(at: updateScript, to: payload.appending(path: "update-agent-tools.sh"))
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: payload.appending(path: "update-agent-tools.sh").path
        )

        let service = AgentToolsUpdateService(homeDirectory: home, bundleResourceURL: resources)
        let availability = try #require(await service.availability())
        #expect(availability.installationKind == .dmg)
        #expect(availability.installedVersion.description == "1.0.4")
        #expect(availability.availableVersion.description == "1.0.5")

        let result = try await service.install(availability)

        #expect(result.version == "1.0.5")
        #expect(try String(contentsOf: installedSkill.appending(path: "SKILL.md"), encoding: .utf8) == "new skill")
        let installedVersion = try run(installedBin.appending(path: "derived"))
        #expect(installedVersion == "derived 1.0.5")
    }

    private func writeExecutable(version: String, to url: URL) throws {
        let script = "#!/bin/zsh\nprint 'derived \(version)'\n"
        try Data(script.utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func run(_ executableURL: URL) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executableURL
        process.arguments = ["--version"]
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

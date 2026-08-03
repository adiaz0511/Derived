@testable import DerivedCLI
import DerivedCore
import Foundation
import Testing

struct CLIUpdateNoticeTests {
    @Test
    func homebrewNoticeUsesIntegrationUpdateCommand() throws {
        let version = try #require(AgentToolsVersion("1.0.4"))
        let releaseURL = try #require(URL(string: "https://example.com/releases/1.0.4"))

        let notice = CLIUpdateNoticeChecker.notice(
            availableVersion: version,
            installationKind: .homebrew,
            releaseURL: releaseURL
        )

        #expect(notice.message.contains("derived integrations update"))
    }

    @Test
    func dmgNoticeProvidesReleaseLocation() throws {
        let version = try #require(AgentToolsVersion("1.0.4"))
        let releaseURL = try #require(URL(string: "https://example.com/releases/1.0.4"))

        let notice = CLIUpdateNoticeChecker.notice(
            availableVersion: version,
            installationKind: .dmg,
            releaseURL: releaseURL
        )

        #expect(notice.message.contains("Open Derived"))
        #expect(notice.message.contains(releaseURL.absoluteString))
    }

    @Test
    func checkerUsesFreshManifestAndWritesCache() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "derived-update-check-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let cacheURL = root.appending(path: "cache.json")
        let releaseURL = try #require(URL(string: "https://example.com/releases/1.0.4"))
        let manifest = AgentToolsUpdateManifest(
            schemaVersion: 1,
            version: "1.0.4",
            releaseURL: releaseURL
        )
        let manifestData = try JSONEncoder().encode(manifest)
        let checker = CLIUpdateNoticeChecker(
            cacheURL: cacheURL,
            currentDate: { Date(timeIntervalSince1970: 1_000) },
            dataLoader: { _ in manifestData }
        )

        let notice = await checker.notice(
            currentVersion: "1.0.3",
            executableURL: URL(fileURLWithPath: "/opt/homebrew/Caskroom/derived-tools/1.0.3/.agent-tools/bin/derived"),
            homeDirectory: URL(fileURLWithPath: "/Users/example")
        )

        #expect(notice?.message.contains("1.0.4") == true)
        #expect(FileManager.default.fileExists(atPath: cacheURL.path))
    }
}

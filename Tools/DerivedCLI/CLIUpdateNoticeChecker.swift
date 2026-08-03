import DerivedCore
import Foundation

struct CLIUpdateNoticeChecker {
    typealias DataLoader = @Sendable (URLRequest) async throws -> Data

    static var defaultManifestURL: URL {
        guard let url = URL(string: "https://adiaz0511.github.io/Derived/tools-version.json") else {
            preconditionFailure("The Agent Tools update URL is invalid.")
        }
        return url
    }
    static let checkInterval: TimeInterval = 24 * 60 * 60

    private let manifestURL: URL
    private let cacheURL: URL
    private let currentDate: @Sendable () -> Date
    private let dataLoader: DataLoader

    init(
        manifestURL: URL = Self.defaultManifestURL,
        cacheURL: URL? = nil,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        currentDate: @escaping @Sendable () -> Date = { .now },
        dataLoader: DataLoader? = nil
    ) {
        self.manifestURL = manifestURL
        self.cacheURL = cacheURL ?? homeDirectory
            .appending(path: "Library/Caches/mx.devlabs.Derived/agent-tools-update.json")
        self.currentDate = currentDate
        self.dataLoader = dataLoader ?? { request in
            try await Self.loadData(for: request)
        }
    }

    func notice(
        currentVersion: String,
        executableURL: URL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) async -> CLIUpdateNotice? {
        guard ProcessInfo.processInfo.environment["DERIVED_NO_UPDATE_CHECK"] != "1",
              let installedVersion = AgentToolsVersion(currentVersion) else {
            return nil
        }

        let manifest = await currentManifest()
        guard let manifest,
              manifest.schemaVersion == 1,
              let availableVersion = manifest.parsedVersion,
              installedVersion < availableVersion else {
            return nil
        }

        let installationKind = AgentToolsInstallationKind.classify(
            executableURL: executableURL,
            homeDirectory: homeDirectory
        )
        return Self.notice(
            availableVersion: availableVersion,
            installationKind: installationKind,
            releaseURL: manifest.releaseURL
        )
    }

    static func notice(
        availableVersion: AgentToolsVersion,
        installationKind: AgentToolsInstallationKind,
        releaseURL: URL
    ) -> CLIUpdateNotice {
        let action = switch installationKind {
        case .homebrew:
            "Run `derived integrations update`."
        case .dmg:
            "Open Derived or download the latest DMG: \(releaseURL.absoluteString)"
        case .manual:
            "Download the latest release: \(releaseURL.absoluteString)"
        }
        return CLIUpdateNotice(
            message: "Derived Agent Tools \(availableVersion) is available.\n\(action)"
        )
    }

    private func currentManifest() async -> AgentToolsUpdateManifest? {
        let now = currentDate()
        if let cache = readCache(), now.timeIntervalSince(cache.checkedAt) < Self.checkInterval {
            return cache.manifest
        }

        var request = URLRequest(url: manifestURL)
        request.timeoutInterval = 1

        do {
            let data = try await dataLoader(request)
            let manifest = try JSONDecoder().decode(AgentToolsUpdateManifest.self, from: data)
            writeCache(CLIUpdateCheckCache(checkedAt: now, manifest: manifest))
            return manifest
        } catch {
            writeCache(CLIUpdateCheckCache(checkedAt: now, manifest: nil))
            return nil
        }
    }

    private func readCache() -> CLIUpdateCheckCache? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(CLIUpdateCheckCache.self, from: data)
    }

    private func writeCache(_ cache: CLIUpdateCheckCache) {
        do {
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(cache)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            // Update checks are advisory and must never affect CLI commands.
        }
    }

    private static func loadData(for request: URLRequest) async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1
        configuration.timeoutIntervalForResource = 1
        let session = URLSession(configuration: configuration)
        let (data, _) = try await session.data(for: request)
        return data
    }
}

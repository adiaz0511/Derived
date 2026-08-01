import Foundation
import Testing
@testable import Derived

struct SelectionRuleTests {
    @Test func derivedDataIsRecommendedAndArchivesAreNot() async throws {
        let temporaryHome = FileManager.default.temporaryDirectory
            .appending(path: "DerivedSelection-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: temporaryHome) }

        let derived = temporaryHome.appending(path: "Library/Developer/Xcode/DerivedData/Example", directoryHint: .isDirectory)
        let archive = temporaryHome.appending(path: "Library/Developer/Xcode/Archives/2026-07-31", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: derived, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 1_024).write(to: derived.appending(path: "artifact"))
        try Data(repeating: 1, count: 2_048).write(to: archive.appending(path: "release.xcarchive"))

        let result = await FileSystemScanner(homeDirectory: temporaryHome).scan(settings: CleanupSettings())
        let derivedItem = try #require(result.items.first { $0.category == .derivedData })
        let archiveItem = try #require(result.items.first { $0.category == .archives })

        #expect(derivedItem.isRecommended)
        #expect(!archiveItem.isRecommended)
        #expect(derivedItem.byteCount > 0)
        #expect(archiveItem.byteCount > 0)
    }

    @Test func runtimesAreNeverRecommended() async throws {
        let runner = StubCommandRunner(output: """
        {
          "devices": {},
          "runtimes": [
            {"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-26-0","name":"iOS 26.0","version":"26.0","isAvailable":true}
          ]
        }
        """)

        let result = await CoreSimulatorScanner(runner: runner).scan(pinnedRuntimeIDs: [])
        let runtime = try #require(result.items.first)

        #expect(!runtime.isRecommended)
        #expect(runtime.runtime?.isNewestForPlatform == true)
    }

    @Test func recentDerivedDataLogsAndCachesAreAlwaysDiscoveredAndRecommended() async throws {
        let temporaryHome = FileManager.default.temporaryDirectory
            .appending(path: "DerivedAllFiles-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: temporaryHome) }

        let candidates: [(String, CleanupCategory)] = [
            ("Library/Developer/Xcode/DerivedData/FreshProject", .derivedData),
            ("Library/Logs/CoreSimulator/Fresh.log", .logs),
            ("Library/Caches/com.apple.dt.Xcode/FreshCache", .caches)
        ]
        for (relativePath, _) in candidates {
            let url = temporaryHome.appending(path: relativePath)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("fresh".utf8).write(to: url)
        }

        let result = await FileSystemScanner(homeDirectory: temporaryHome).scan(settings: CleanupSettings())

        for (_, category) in candidates {
            let item = try #require(result.items.first { $0.category == category })
            #expect(item.isRecommended)
        }
    }

    @Test func deviceSupportAgeControlsRecommendationWithoutFilteringScanResults() async throws {
        let temporaryHome = FileManager.default.temporaryDirectory
            .appending(path: "DerivedDeviceSupport-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: temporaryHome) }

        let recentDate = try #require(Calendar.current.date(byAdding: .day, value: -10, to: .now))
        let oldDate = try #require(Calendar.current.date(byAdding: .day, value: -120, to: .now))
        let candidates = [
            ("Library/Developer/Xcode/iOS DeviceSupport/iOS Recent", recentDate),
            ("Library/Developer/Xcode/iOS DeviceSupport/iOS Old", oldDate),
            ("Library/Developer/Xcode/watchOS DeviceSupport/watchOS Recent", recentDate),
            ("Library/Developer/Xcode/watchOS DeviceSupport/watchOS Old", oldDate)
        ]

        for (relativePath, modifiedAt) in candidates {
            let directory = temporaryHome.appending(path: relativePath, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("symbols".utf8).write(to: directory.appending(path: "symbols"))
            try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: directory.path)
        }

        var settings = CleanupSettings()
        settings.preselectOldDeviceSupport = true
        settings.deviceSupportMinimumAgeDays = 90

        let result = await FileSystemScanner(homeDirectory: temporaryHome).scan(settings: settings)
        let deviceSupport = result.items.filter { $0.category == .deviceSupport }

        #expect(deviceSupport.count == 4)
        #expect(deviceSupport.first { $0.name == "iOS Recent" }?.isRecommended == false)
        #expect(deviceSupport.first { $0.name == "watchOS Recent" }?.isRecommended == false)
        #expect(deviceSupport.first { $0.name == "iOS Old" }?.isRecommended == true)
        #expect(deviceSupport.first { $0.name == "watchOS Old" }?.isRecommended == true)
    }
}

private actor StubCommandRunner: CommandRunning {
    let output: String

    init(output: String) {
        self.output = output
    }

    func run(executable: String, arguments: [String]) async throws -> CommandResult {
        CommandResult(executable: executable, arguments: arguments, standardOutput: output, standardError: "", exitCode: 0)
    }
}

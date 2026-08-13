import Foundation
import Testing
@testable import Derived

struct RuntimeDetectionTests {
    @Test func selectsHighestAvailableRuntimeForEachPlatform() throws {
        let json = """
        {
          "runtimes": [
            {"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-18-5","name":"iOS 18.5","version":"18.5","buildversion":"22F76","isAvailable":true},
            {"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-26-0","name":"iOS 26.0","version":"26.0","buildversion":"23A123","isAvailable":true},
            {"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-27-0","name":"iOS 27.0","version":"27.0","buildversion":"24A1","isAvailable":false},
            {"identifier":"com.apple.CoreSimulator.SimRuntime.watchOS-26-0","name":"watchOS 26.0","version":"26.0","buildversion":"23R12","isAvailable":true}
          ]
        }
        """

        let ids = try CoreSimulatorScanner.newestRuntimeIDs(from: Data(json.utf8))

        #expect(ids.contains("com.apple.CoreSimulator.SimRuntime.iOS-26-0"))
        #expect(ids.contains("com.apple.CoreSimulator.SimRuntime.watchOS-26-0"))
        #expect(!ids.contains("com.apple.CoreSimulator.SimRuntime.iOS-27-0"))
    }

    @Test func mapsRuntimeIdentifiersToPhysicalDiskImageInformation() throws {
        let json = """
        {
          "5506559C-45FD-409E-B1BB-E749E40D53A8": {
            "identifier": "5506559C-45FD-409E-B1BB-E749E40D53A8",
            "runtimeIdentifier": "com.apple.CoreSimulator.SimRuntime.watchOS-26-5",
            "sizeBytes": 3935033546
          }
        }
        """

        let information = try CoreSimulatorScanner.runtimeDiskImageInformation(from: Data(json.utf8))
        let watchRuntime = try #require(information["com.apple.CoreSimulator.SimRuntime.watchOS-26-5"])

        #expect(watchRuntime.deletionIdentifier == "5506559C-45FD-409E-B1BB-E749E40D53A8")
        #expect(watchRuntime.sizeBytes == 3_935_033_546)
    }

    @Test func excludesUnavailableRuntimesFromScanResults() async throws {
        let runner = RuntimeInventoryRunner(
            runtimes: """
            {
              "devices": {},
              "runtimes": [
                {"identifier":"com.apple.CoreSimulator.SimRuntime.watchOS-26-5","name":"watchOS 26.5","version":"26.5","isAvailable":false},
                {"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-26-5","name":"iOS 26.5","version":"26.5","isAvailable":true}
              ]
            }
            """,
            diskImages: "{}"
        )

        let result = await CoreSimulatorScanner(runner: runner).scan(pinnedRuntimeIDs: [])

        #expect(result.items.map(\.runtime?.id) == ["com.apple.CoreSimulator.SimRuntime.iOS-26-5"])
    }
}

private actor RuntimeInventoryRunner: CommandRunning {
    let runtimes: String
    let diskImages: String

    init(runtimes: String, diskImages: String) {
        self.runtimes = runtimes
        self.diskImages = diskImages
    }

    func run(executable: String, arguments: [String]) async throws -> CommandResult {
        let output = arguments == ["simctl", "runtime", "list", "--json"] ? diskImages : runtimes
        return CommandResult(
            executable: executable,
            arguments: arguments,
            standardOutput: output,
            standardError: "",
            exitCode: 0
        )
    }
}

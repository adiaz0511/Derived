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
}

import Foundation
import Testing
@testable import Derived

struct PathValidatorTests {
    private let root = URL(filePath: "/tmp/DerivedTests/DerivedData", directoryHint: .isDirectory)

    @Test func acceptsChildOfAllowlistedRoot() {
        let validator = PathValidator(allowedRoots: [root])
        let result = validator.validateFileSystemPath(root.appending(path: "Example-hash").path)

        #expect(result.isValid)
    }

    @Test func rejectsRootItself() {
        let validator = PathValidator(allowedRoots: [root])
        let result = validator.validateFileSystemPath(root.path)

        #expect(!result.isValid)
    }

    @Test func rejectsProjectSourceOutsideAllowlist() {
        let validator = PathValidator(allowedRoots: [root])
        let result = validator.validateFileSystemPath("/Users/example/Projects/Application/Sources")

        #expect(!result.isValid)
    }

    @Test func acceptsRuntimeDiskImageIdentifier() {
        let identifier = "5506559C-45FD-409E-B1BB-E749E40D53A8"
        let item = CleanupItem(
            id: "runtime:com.apple.CoreSimulator.SimRuntime.watchOS-26-5",
            name: "watchOS 26.5",
            category: .simulatorRuntimes,
            byteCount: 0,
            path: "simctl://runtime/com.apple.CoreSimulator.SimRuntime.watchOS-26-5",
            modifiedAt: nil,
            safety: .highRisk,
            reason: "Newest runtime",
            isRecommended: false,
            removalMethod: .simulatorRuntime(identifier: identifier),
            runtime: nil,
            isActive: false
        )

        #expect(PathValidator(allowedRoots: [root]).validate(item).isValid)
    }
}

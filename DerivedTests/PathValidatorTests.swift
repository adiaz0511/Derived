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
}

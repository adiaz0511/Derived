import Foundation
import Testing
@testable import Derived

struct FileRemoverTests {
    @Test func permanentlyRemovesDirectoryWithoutUsingTrash() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DerivedFileRemover-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("test".utf8).write(to: directory.appending(path: "artifact"))

        try await FoundationFileRemover().removeItem(at: directory)

        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }
}

import Foundation

nonisolated protocol FileRemoving: Sendable {
    func removeItem(at url: URL) async throws
}

actor FoundationFileRemover: FileRemoving {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func removeItem(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }
}

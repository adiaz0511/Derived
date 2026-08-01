import Foundation

nonisolated struct PathValidationResult: Equatable, Sendable {
    let isValid: Bool
    let message: String
}

nonisolated struct PathValidator: Sendable {
    let allowedRoots: [URL]

    init(homeDirectory: URL = .homeDirectory) {
        allowedRoots = Self.defaultAllowedRoots(homeDirectory: homeDirectory)
    }

    init(allowedRoots: [URL]) {
        self.allowedRoots = allowedRoots
    }

    func validate(_ item: CleanupItem) -> PathValidationResult {
        switch item.removalMethod {
        case .simulatorDevice(let udid):
            return validateIdentifier(udid, kind: "simulator device")
        case .simulatorRuntime(let identifier):
            return validateRuntimeIdentifier(identifier)
        case .fileSystem:
            return validateFileSystemPath(item.path)
        }
    }

    func validateFileSystemPath(_ path: String) -> PathValidationResult {
        guard path.hasPrefix("/") else {
            return .init(isValid: false, message: "The target is not an absolute path.")
        }

        let target = URL(filePath: path).standardizedFileURL.resolvingSymlinksInPath()
        let matchingRoot = allowedRoots.first { root in
            let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath()
            return target.path == resolvedRoot.path || target.path.hasPrefix(resolvedRoot.path + "/")
        }

        guard let matchingRoot else {
            return .init(isValid: false, message: "The target is outside all approved Xcode storage roots.")
        }

        let resolvedRoot = matchingRoot.standardizedFileURL.resolvingSymlinksInPath()
        guard target.path != resolvedRoot.path else {
            return .init(isValid: false, message: "Category root directories cannot be removed as a single target.")
        }

        return .init(isValid: true, message: "Validated within \(resolvedRoot.path).")
    }

    static func defaultAllowedRoots(homeDirectory: URL) -> [URL] {
        [
            "Library/Developer/Xcode/DerivedData",
            "Library/Developer/Xcode/Archives",
            "Library/Developer/Xcode/iOS DeviceSupport",
            "Library/Developer/Xcode/watchOS DeviceSupport",
            "Library/Developer/Xcode/UserData/Previews",
            "Library/Developer/Xcode/UserData/IB Support",
            "Library/Developer/CoreSimulator/Devices",
            "Library/Developer/CoreSimulator/Caches",
            "Library/Developer/XCTestDevices",
            "Library/Caches/com.apple.dt.Xcode",
            "Library/Logs/CoreSimulator",
            "Library/Logs/DiagnosticReports"
        ].map { homeDirectory.appending(path: $0, directoryHint: .isDirectory) }
    }

    private func validateIdentifier(_ identifier: String, kind: String) -> PathValidationResult {
        guard UUID(uuidString: identifier) != nil else {
            return .init(isValid: false, message: "The \(kind) identifier is not a valid UUID.")
        }
        return .init(isValid: true, message: "Validated for removal through xcrun simctl.")
    }

    private func validateRuntimeIdentifier(_ identifier: String) -> PathValidationResult {
        let prefix = "com.apple.CoreSimulator.SimRuntime."
        guard identifier.hasPrefix(prefix), identifier.count > prefix.count else {
            return .init(isValid: false, message: "The runtime identifier is not recognized.")
        }
        return .init(isValid: true, message: "Validated for removal through xcrun simctl runtime delete.")
    }
}

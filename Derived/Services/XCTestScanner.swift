import Foundation

actor XCTestScanner {
    private struct SimctlPayload: Decodable {
        let devices: [String: [SimctlDevice]]
    }

    private struct SimctlDevice: Decodable {
        let udid: String
        let name: String
        let state: String
        let dataPathSize: Int64?
    }

    private struct DeviceMetadata: Decodable {
        let name: String?
        let isDeleted: Bool?
        let isEphemeral: Bool?
        let state: Int?
        let UDID: String?
    }

    private let runner: any CommandRunning
    private let fileManager: FileManager
    private let root: URL

    init(
        runner: any CommandRunning = FoundationCommandRunner(),
        fileManager: FileManager = .default,
        homeDirectory: URL = .homeDirectory
    ) {
        self.runner = runner
        self.fileManager = fileManager
        root = homeDirectory.appending(path: "Library/Developer/XCTestDevices", directoryHint: .isDirectory)
    }

    func scan() async -> (items: [CleanupItem], warnings: [String]) {
        guard fileManager.fileExists(atPath: root.path) else { return ([], []) }

        let simctlDevices = await loadSimctlDevices()
        do {
            let directories = try fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            let items = directories.compactMap { makeItem(at: $0, simctlDevices: simctlDevices) }
            return (items, [])
        } catch {
            return ([], ["Could not scan \(root.path): \(error.localizedDescription)"])
        }
    }

    private func loadSimctlDevices() async -> [String: SimctlDevice] {
        do {
            let result = try await runner.run(
                executable: "/usr/bin/xcrun",
                arguments: ["simctl", "--set", root.path, "list", "--json", "devices"]
            )
            guard result.succeeded else { return [:] }
            guard let payload = try? JSONDecoder().decode(SimctlPayload.self, from: Data(result.standardOutput.utf8)) else { return [:] }
            let devices = payload.devices.values.flatMap { $0 }
            return Dictionary(uniqueKeysWithValues: devices.map { ($0.udid, $0) })
        } catch {
            return [:]
        }
    }

    private func makeItem(at directory: URL, simctlDevices: [String: SimctlDevice]) -> CleanupItem? {
        guard UUID(uuidString: directory.lastPathComponent) != nil else { return nil }
        let metadataURL = directory.appending(path: "device.plist")
        guard let data = try? Data(contentsOf: metadataURL),
              let metadata = try? PropertyListDecoder().decode(DeviceMetadata.self, from: data) else {
            return nil
        }

        let udid = metadata.UDID ?? directory.lastPathComponent
        let simctlDevice = simctlDevices[udid]
        let state = simctlDevice?.state ?? (metadata.state == 3 ? "Booted" : "Shutdown")
        let isActive = state.localizedCaseInsensitiveCompare("Booted") == .orderedSame
        let isDeleted = metadata.isDeleted == true
        let isEphemeral = metadata.isEphemeral == true
        let hasLogicalSize = simctlDevice?.dataPathSize != nil
        let modifiedAt = try? directory.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

        return CleanupItem(
            id: "xctest:\(udid)",
            name: simctlDevice?.name ?? metadata.name ?? "XCTest Device \(udid)",
            category: .xctestDevices,
            byteCount: simctlDevice?.dataPathSize ?? shallowAllocatedSize(of: directory),
            path: directory.path,
            modifiedAt: modifiedAt ?? nil,
            safety: isActive ? .highRisk : (isDeleted ? .recommended : .caution),
            reason: reason(isDeleted: isDeleted, isEphemeral: isEphemeral, hasLogicalSize: hasLogicalSize),
            isRecommended: !isActive && (isDeleted || isEphemeral),
            removalMethod: .fileSystem,
            runtime: nil,
            isActive: isActive,
            sizeClassification: hasLogicalSize ? .apfsCloneLogical : .verified
        )
    }

    private func shallowAllocatedSize(of directory: URL) -> Int64 {
        guard let children = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        return children.reduce(0) { total, child in
            guard let values = try? child.resourceValues(forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]),
                  values.isRegularFile == true else { return total }
            return total + Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
    }

    private func reason(isDeleted: Bool, isEphemeral: Bool, hasLogicalSize: Bool) -> String {
        let status: String
        if isDeleted {
            status = "XCTest marked this clone as deleted."
        } else if isEphemeral {
            status = "XCTest marked this as an ephemeral clone."
        } else {
            status = "This persistent clone is not selected automatically."
        }
        let sizeNote = hasLogicalSize
            ? " The displayed size is logical and includes APFS-shared blocks."
            : ""
        return status + sizeNote
    }
}

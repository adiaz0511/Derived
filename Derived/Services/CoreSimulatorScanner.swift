import Foundation

actor CoreSimulatorScanner {
    private struct SimctlPayload: Decodable {
        let devices: [String: [Device]]?
        let runtimes: [Runtime]?
    }

    private struct Device: Decodable {
        let name: String
        let udid: String
        let state: String
        let isAvailable: Bool?
        let dataPath: String?
        let dataPathSize: Int64?
        let lastBootedAt: String?
    }

    private struct Runtime: Decodable {
        let identifier: String
        let name: String
        let version: String
        let buildversion: String?
        let isAvailable: Bool?
        let bundlePath: String?
    }

    private let runner: any CommandRunning

    init(runner: any CommandRunning = FoundationCommandRunner()) {
        self.runner = runner
    }

    func scan(pinnedRuntimeIDs: Set<String>) async -> (items: [CleanupItem], warnings: [String]) {
        do {
            let result = try await runner.run(
                executable: "/usr/bin/xcrun",
                arguments: ["simctl", "list", "--json", "devices", "runtimes"]
            )
            guard result.succeeded else {
                let detail = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
                return ([], ["simctl discovery failed: \(detail)"])
            }

            let payload = try JSONDecoder().decode(SimctlPayload.self, from: Data(result.standardOutput.utf8))
            let runtimes = payload.runtimes ?? []
            let newestIDs = Self.newestRuntimeIDs(runtimes: runtimes)
            let runtimeItems = runtimes.map { runtime in
                makeRuntimeItem(runtime, isNewest: newestIDs.contains(runtime.identifier), isPinned: pinnedRuntimeIDs.contains(runtime.identifier))
            }
            let deviceItems = makeDeviceItems(payload.devices ?? [:])
            return (runtimeItems + deviceItems, [])
        } catch {
            return ([], ["simctl output could not be read: \(error.localizedDescription)"])
        }
    }

    private func makeRuntimeItem(_ runtime: Runtime, isNewest: Bool, isPinned: Bool) -> CleanupItem {
        let platform = Self.platform(for: runtime)
        let isPrerelease = Self.isPrerelease(name: runtime.name, version: runtime.version, buildVersion: runtime.buildversion)
        let information = RuntimeInformation(
            id: runtime.identifier,
            name: runtime.name,
            platform: platform,
            version: runtime.version,
            buildVersion: runtime.buildversion,
            isPrerelease: isPrerelease,
            isNewestForPlatform: isNewest,
            isAvailable: runtime.isAvailable ?? true
        )
        let warnings = [
            isNewest ? "This is the newest installed \(platform.rawValue) runtime." : nil,
            isPinned ? "This runtime is pinned in Settings." : nil,
            isPrerelease ? "This is a beta or prerelease runtime." : nil
        ].compactMap { $0 }.joined(separator: " ")

        return CleanupItem(
            id: "runtime:\(runtime.identifier)",
            name: runtime.name,
            category: .simulatorRuntimes,
            byteCount: Self.directorySize(at: runtime.bundlePath),
            path: runtime.bundlePath ?? "simctl://runtime/\(runtime.identifier)",
            modifiedAt: nil,
            safety: (isNewest || isPinned) ? .highRisk : .caution,
            reason: "Installed runtimes support simulator devices. They are never selected automatically. \(warnings)",
            isRecommended: false,
            removalMethod: .simulatorRuntime(identifier: runtime.identifier),
            runtime: information,
            isActive: false
        )
    }

    private func makeDeviceItems(_ devicesByRuntime: [String: [Device]]) -> [CleanupItem] {
        var items: [CleanupItem] = []
        for (_, devices) in devicesByRuntime {
            let groups = Dictionary(grouping: devices, by: \.name)
            for device in devices {
                let isBooted = device.state.localizedCaseInsensitiveCompare("Booted") == .orderedSame
                let unavailable = device.isAvailable == false
                let redundant = !unavailable && (groups[device.name]?.count ?? 0) > 1
                guard unavailable || redundant else { continue }

                let category: CleanupCategory = unavailable ? .unavailableSimulators : .redundantSimulators
                let lastBooted = device.lastBootedAt.flatMap { try? Date($0, strategy: .iso8601) }
                let reason = unavailable
                    ? "The simulator runtime is unavailable, so this device cannot currently boot."
                    : "Another simulator device has the same name and runtime. Review before removal."

                items.append(CleanupItem(
                    id: "device:\(device.udid)",
                    name: device.name,
                    category: category,
                    byteCount: device.dataPathSize ?? Self.directorySize(at: device.dataPath),
                    path: device.dataPath ?? "simctl://device/\(device.udid)",
                    modifiedAt: lastBooted,
                    safety: isBooted ? .highRisk : .caution,
                    reason: isBooted ? "This device is currently booted and is not recommended. \(reason)" : reason,
                    isRecommended: unavailable && !isBooted,
                    removalMethod: .simulatorDevice(udid: device.udid),
                    runtime: nil,
                    isActive: isBooted
                ))
            }
        }
        return items
    }

    static func newestRuntimeIDs(from data: Data) throws -> Set<String> {
        let payload = try JSONDecoder().decode(SimctlPayload.self, from: data)
        return newestRuntimeIDs(runtimes: payload.runtimes ?? [])
    }

    private static func newestRuntimeIDs(runtimes: [Runtime]) -> Set<String> {
        let available = runtimes.filter { $0.isAvailable ?? true }
        let grouped = Dictionary(grouping: available, by: platform(for:))
        return Set(grouped.compactMap { _, platformRuntimes in
            platformRuntimes.max { versionComponents($0.version).lexicographicallyPrecedes(versionComponents($1.version)) }?.identifier
        })
    }

    private static func platform(for runtime: Runtime) -> RuntimeInformation.Platform {
        let value = runtime.identifier + " " + runtime.name
        if value.localizedStandardContains("visionOS") || value.localizedStandardContains("xrOS") { return .visionOS }
        if value.localizedStandardContains("watchOS") { return .watchOS }
        if value.localizedStandardContains("tvOS") { return .tvOS }
        if value.localizedStandardContains("iOS") { return .iOS }
        if value.localizedStandardContains("macOS") { return .macOS }
        return .unknown
    }

    private static func isPrerelease(name: String, version: String, buildVersion: String?) -> Bool {
        let value = [name, version, buildVersion ?? ""].joined(separator: " ")
        return value.localizedStandardContains("beta") || value.localizedStandardContains("rc") || value.localizedStandardContains("seed")
    }

    private static func versionComponents(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }

    private static func directorySize(at path: String?) -> Int64 {
        guard let path else { return 0 }
        let url = URL(filePath: path)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isSymbolicLinkKey],
            options: []
        ) else { return 0 }

        var total: Int64 = 0
        for case let itemURL as URL in enumerator {
            guard let values = try? itemURL.resourceValues(forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isSymbolicLinkKey]),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }
}

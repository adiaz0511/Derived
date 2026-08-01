import Foundation

actor FileSystemScanner {
    struct ScanLocation: Sendable {
        let relativePath: String
        let category: CleanupCategory
        let safety: SafetyClassification
        let reason: String
        let minimumAge: @Sendable (CleanupSettings) -> Int
        let isRecommended: @Sendable (Int, CleanupSettings) -> Bool
    }

    private let fileManager: FileManager
    private let homeDirectory: URL

    init(fileManager: FileManager = .default, homeDirectory: URL = .homeDirectory) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
    }

    func scan(settings: CleanupSettings) -> (items: [CleanupItem], warnings: [String]) {
        var items: [CleanupItem] = []
        var warnings: [String] = []

        for location in Self.locations {
            let root = homeDirectory.appending(path: location.relativePath, directoryHint: .isDirectory)
            guard fileManager.fileExists(atPath: root.path) else { continue }

            do {
                let children = try fileManager.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                )

                for child in children {
                    guard !isSymbolicLink(child) else {
                        warnings.append("Skipped symbolic link: \(child.path)")
                        continue
                    }

                    let modifiedAt = resourceValues(for: child).contentModificationDate
                    let age = ageInDays(since: modifiedAt)
                    guard age >= location.minimumAge(settings) else { continue }

                    items.append(CleanupItem(
                        id: "file:\(child.path)",
                        name: child.lastPathComponent,
                        category: location.category,
                        byteCount: allocatedSize(of: child),
                        path: child.path,
                        modifiedAt: modifiedAt,
                        safety: location.safety,
                        reason: location.reason,
                        isRecommended: location.isRecommended(age, settings),
                        removalMethod: .fileSystem,
                        runtime: nil,
                        isActive: false
                    ))
                }
            } catch {
                warnings.append("Could not scan \(root.path): \(error.localizedDescription)")
            }
        }

        return (items, warnings)
    }

    private func allocatedSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .isSymbolicLinkKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: []
        ) else {
            return Int64(resourceValues(for: url).fileSize ?? 0)
        }

        var total: Int64 = 0
        for case let itemURL as URL in enumerator {
            guard let values = try? itemURL.resourceValues(forKeys: keys), values.isSymbolicLink != true else { continue }
            if values.isRegularFile == true {
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            }
        }
        return total
    }

    private func resourceValues(for url: URL) -> URLResourceValues {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isSymbolicLinkKey])) ?? URLResourceValues()
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        resourceValues(for: url).isSymbolicLink == true
    }

    private func ageInDays(since date: Date?) -> Int {
        guard let date else { return .max }
        return max(0, Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0)
    }

    static let locations: [ScanLocation] = [
        .init(
            relativePath: "Library/Developer/Xcode/DerivedData",
            category: .derivedData,
            safety: .recommended,
            reason: "Xcode regenerates build products, indexes, and intermediate files when the project is built again.",
            minimumAge: { _ in 0 },
            isRecommended: { _, _ in true }
        ),
        .init(
            relativePath: "Library/Developer/Xcode/UserData/Previews",
            category: .previewData,
            safety: .recommended,
            reason: "SwiftUI recreates preview simulator data when a preview runs again.",
            minimumAge: { _ in 0 },
            isRecommended: { _, _ in true }
        ),
        .init(
            relativePath: "Library/Developer/Xcode/iOS DeviceSupport",
            category: .deviceSupport,
            safety: .caution,
            reason: "Xcode may recreate support files the next time a matching physical device is connected.",
            minimumAge: { _ in 0 },
            isRecommended: { age, settings in settings.preselectOldDeviceSupport && age >= settings.deviceSupportMinimumAgeDays }
        ),
        .init(
            relativePath: "Library/Developer/Xcode/watchOS DeviceSupport",
            category: .deviceSupport,
            safety: .caution,
            reason: "Xcode may recreate support files the next time a matching physical device is connected.",
            minimumAge: { _ in 0 },
            isRecommended: { age, settings in settings.preselectOldDeviceSupport && age >= settings.deviceSupportMinimumAgeDays }
        ),
        .init(
            relativePath: "Library/Logs/CoreSimulator",
            category: .logs,
            safety: .recommended,
            reason: "CoreSimulator log files are diagnostic records and are not required for normal simulator operation.",
            minimumAge: { _ in 0 },
            isRecommended: { _, _ in true }
        ),
        .init(
            relativePath: "Library/Caches/com.apple.dt.Xcode",
            category: .caches,
            safety: .recommended,
            reason: "This documented Xcode cache is regenerated as Xcode is used.",
            minimumAge: { _ in 0 },
            isRecommended: { _, _ in true }
        ),
        .init(
            relativePath: "Library/Developer/CoreSimulator/Caches",
            category: .caches,
            safety: .recommended,
            reason: "CoreSimulator regenerates these cache entries when required.",
            minimumAge: { _ in 0 },
            isRecommended: { _, _ in true }
        ),
        .init(
            relativePath: "Library/Developer/Xcode/Archives",
            category: .archives,
            safety: .highRisk,
            reason: "Archives may contain the only retained build and dSYM for a released application.",
            minimumAge: { _ in 0 },
            isRecommended: { _, _ in false }
        ),
        .init(
            relativePath: "Library/Developer/Xcode/UserData/IB Support",
            category: .temporaryData,
            safety: .caution,
            reason: "Interface Builder creates support data here and may recreate it when required.",
            minimumAge: { _ in 30 },
            isRecommended: { _, _ in false }
        )
    ]
}

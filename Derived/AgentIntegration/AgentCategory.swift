import Foundation

nonisolated public enum AgentCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case derivedData
    case previewData
    case xctestDevices
    case unavailableSimulators
    case redundantSimulators
    case simulatorRuntimes
    case deviceSupport
    case logs
    case caches
    case archives
    case temporaryData

    public var id: Self { self }

    public var title: String {
        cleanupCategory.title
    }

    var cleanupCategory: CleanupCategory {
        CleanupCategory(rawValue: rawValue) ?? .temporaryData
    }

    init(_ category: CleanupCategory) {
        self = AgentCategory(rawValue: category.rawValue) ?? .temporaryData
    }
}

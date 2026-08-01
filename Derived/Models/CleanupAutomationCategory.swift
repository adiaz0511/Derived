import Foundation

nonisolated enum CleanupAutomationCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case derivedData
    case logs
    case caches

    var id: Self { self }

    var title: String {
        switch self {
        case .derivedData: "Derived Data"
        case .logs: "Xcode Logs"
        case .caches: "Xcode Caches"
        }
    }

    var cleanupCategory: CleanupCategory {
        switch self {
        case .derivedData: .derivedData
        case .logs: .logs
        case .caches: .caches
        }
    }

    var symbolName: String {
        cleanupCategory.symbolName
    }
}

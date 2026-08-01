import Foundation

nonisolated struct CleanupSettings: Codable, Equatable, Sendable {
    var derivedDataAutomation = CleanupAutomationRule()
    var logsAutomation = CleanupAutomationRule()
    var cachesAutomation = CleanupAutomationRule()
    var deviceSupportMinimumAgeDays = 90
    var preselectOldDeviceSupport = false
    var pinnedRuntimeIDs: Set<String> = []

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        derivedDataAutomation = try container.decodeIfPresent(CleanupAutomationRule.self, forKey: .derivedDataAutomation) ?? CleanupAutomationRule()
        logsAutomation = try container.decodeIfPresent(CleanupAutomationRule.self, forKey: .logsAutomation) ?? CleanupAutomationRule()
        cachesAutomation = try container.decodeIfPresent(CleanupAutomationRule.self, forKey: .cachesAutomation) ?? CleanupAutomationRule()
        deviceSupportMinimumAgeDays = try container.decodeIfPresent(Int.self, forKey: .deviceSupportMinimumAgeDays) ?? 90
        preselectOldDeviceSupport = try container.decodeIfPresent(Bool.self, forKey: .preselectOldDeviceSupport) ?? false
        pinnedRuntimeIDs = try container.decodeIfPresent(Set<String>.self, forKey: .pinnedRuntimeIDs) ?? []
    }

    subscript(automation category: CleanupAutomationCategory) -> CleanupAutomationRule {
        get {
            switch category {
            case .derivedData: derivedDataAutomation
            case .logs: logsAutomation
            case .caches: cachesAutomation
            }
        }
        set {
            switch category {
            case .derivedData: derivedDataAutomation = newValue
            case .logs: logsAutomation = newValue
            case .caches: cachesAutomation = newValue
            }
        }
    }

    func dueAutomationCategories(
        at date: Date,
        calendar: Calendar = .current
    ) -> [CleanupAutomationCategory] {
        CleanupAutomationCategory.allCases.filter {
            self[automation: $0].isDue(at: date, calendar: calendar)
        }
    }
}

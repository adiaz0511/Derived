import Foundation
import Observation

@Observable
final class SettingsStore {
    private static let key = "cleanupSettings"
    private static let legacyKey = "retentionSettings"
    private static let legacySuiteName = "mx.devlabs.XcodeClean"
    private let defaults: UserDefaults

    var settings: CleanupSettings {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let legacyDefaults = defaults === UserDefaults.standard
            ? UserDefaults(suiteName: Self.legacySuiteName)
            : nil
        let storedData = defaults.data(forKey: Self.key)
            ?? defaults.data(forKey: Self.legacyKey)
            ?? legacyDefaults?.data(forKey: Self.legacyKey)

        if let storedData,
           let stored = try? JSONDecoder().decode(CleanupSettings.self, from: storedData) {
            settings = stored
            defaults.set(storedData, forKey: Self.key)
        } else {
            settings = CleanupSettings()
        }
    }

    func automationRule(for category: CleanupAutomationCategory) -> CleanupAutomationRule {
        settings[automation: category]
    }

    func setAutomationEnabled(
        _ isEnabled: Bool,
        category: CleanupAutomationCategory,
        at date: Date = .now
    ) {
        var rule = settings[automation: category]
        rule.isEnabled = isEnabled
        rule.enabledAt = isEnabled ? date : nil
        settings[automation: category] = rule
    }

    func setAutomationFrequency(
        _ frequency: CleanupFrequency,
        category: CleanupAutomationCategory
    ) {
        var rule = settings[automation: category]
        rule.frequency = frequency
        settings[automation: category] = rule
    }

    func markAutomationRun(
        categories: some Sequence<CleanupAutomationCategory>,
        at date: Date
    ) {
        for category in categories {
            var rule = settings[automation: category]
            rule.lastRunAt = date
            settings[automation: category] = rule
        }
    }

    func setPinned(_ isPinned: Bool, runtimeID: String) {
        if isPinned {
            settings.pinnedRuntimeIDs.insert(runtimeID)
        } else {
            settings.pinnedRuntimeIDs.remove(runtimeID)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

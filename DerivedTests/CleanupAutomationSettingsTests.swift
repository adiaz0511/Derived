import Foundation
import Testing
@testable import Derived

struct CleanupAutomationSettingsTests {
    @Test func enabledRuleBecomesDueAtItsScheduledDate() throws {
        let calendar = utcCalendar
        let enabledAt = try Date("2026-07-01T12:00:00Z", strategy: .iso8601)
        var rule = CleanupAutomationRule()
        rule.isEnabled = true
        rule.frequency = .weekly
        rule.enabledAt = enabledAt

        let nextRun = try #require(rule.nextRunDate(calendar: calendar))

        #expect(nextRun == (try Date("2026-07-08T12:00:00Z", strategy: .iso8601)))
        #expect(!rule.isDue(at: nextRun.addingTimeInterval(-1), calendar: calendar))
        #expect(rule.isDue(at: nextRun, calendar: calendar))
    }

    @Test func reenabledRuleSchedulesFromMostRecentEnablement() throws {
        let calendar = utcCalendar
        var rule = CleanupAutomationRule()
        rule.isEnabled = true
        rule.frequency = .daily
        rule.lastRunAt = try Date("2026-07-01T12:00:00Z", strategy: .iso8601)
        rule.enabledAt = try Date("2026-07-10T12:00:00Z", strategy: .iso8601)

        #expect(rule.nextRunDate(calendar: calendar) == (try Date("2026-07-11T12:00:00Z", strategy: .iso8601)))
    }

    @Test func legacySettingsPreservePreferencesButDoNotEnableAutomations() throws {
        let legacyData = Data("""
        {
          "derivedDataMinimumAgeDays": 30,
          "logsMinimumAgeDays": 14,
          "cacheMinimumAgeDays": 7,
          "deviceSupportMinimumAgeDays": 120,
          "preselectOldDeviceSupport": true,
          "pinnedRuntimeIDs": ["runtime-id"]
        }
        """.utf8)

        let settings = try JSONDecoder().decode(CleanupSettings.self, from: legacyData)

        #expect(!settings.derivedDataAutomation.isEnabled)
        #expect(!settings.logsAutomation.isEnabled)
        #expect(!settings.cachesAutomation.isEnabled)
        #expect(settings.deviceSupportMinimumAgeDays == 120)
        #expect(settings.preselectOldDeviceSupport)
        #expect(settings.pinnedRuntimeIDs == ["runtime-id"])
    }

    @Test func settingsRoundTripPreservesAutomationSchedules() throws {
        let enabledAt = try Date("2026-07-10T12:00:00Z", strategy: .iso8601)
        var settings = CleanupSettings()
        settings.derivedDataAutomation = CleanupAutomationRule(
            isEnabled: true,
            frequency: .daily,
            enabledAt: enabledAt,
            lastRunAt: nil
        )
        settings.logsAutomation.frequency = .monthly
        settings.pinnedRuntimeIDs = ["runtime-id"]

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(CleanupSettings.self, from: data)

        #expect(decoded == settings)
    }

    @Test func dueCategoriesIncludeOnlyEnabledElapsedSchedules() throws {
        let enabledAt = try Date("2026-07-01T12:00:00Z", strategy: .iso8601)
        let checkDate = try Date("2026-07-09T12:00:00Z", strategy: .iso8601)
        var settings = CleanupSettings()
        settings.derivedDataAutomation = CleanupAutomationRule(
            isEnabled: true,
            frequency: .weekly,
            enabledAt: enabledAt,
            lastRunAt: nil
        )
        settings.logsAutomation = CleanupAutomationRule(
            isEnabled: true,
            frequency: .monthly,
            enabledAt: enabledAt,
            lastRunAt: nil
        )

        let due = settings.dueAutomationCategories(at: checkDate, calendar: utcCalendar)

        #expect(due == [.derivedData])
    }

    @Test func settingsStoreMigratesTheLegacyPreferenceKey() throws {
        let suiteName = "DerivedTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var legacySettings = CleanupSettings()
        legacySettings.preselectOldDeviceSupport = true
        legacySettings.pinnedRuntimeIDs = ["runtime-id"]
        defaults.set(
            try JSONEncoder().encode(legacySettings),
            forKey: "retentionSettings"
        )

        let store = SettingsStore(defaults: defaults)

        #expect(store.settings == legacySettings)
        #expect(defaults.data(forKey: "cleanupSettings") != nil)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }
}

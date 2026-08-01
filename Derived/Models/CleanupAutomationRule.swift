import Foundation

nonisolated struct CleanupAutomationRule: Codable, Equatable, Sendable {
    var isEnabled = false
    var frequency: CleanupFrequency = .weekly
    var enabledAt: Date?
    var lastRunAt: Date?

    var scheduleAnchor: Date? {
        [enabledAt, lastRunAt].compactMap { $0 }.max()
    }

    func nextRunDate(calendar: Calendar = .current) -> Date? {
        guard isEnabled, let scheduleAnchor else { return nil }
        return frequency.nextDate(after: scheduleAnchor, calendar: calendar)
    }

    func isDue(at date: Date, calendar: Calendar = .current) -> Bool {
        guard let nextRunDate = nextRunDate(calendar: calendar) else { return false }
        return nextRunDate <= date
    }
}

import Foundation

nonisolated enum CleanupFrequency: String, CaseIterable, Codable, Identifiable, Sendable {
    case daily
    case weekly
    case monthly

    var id: Self { self }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }

    var menuTitle: String {
        switch self {
        case .daily: "Day"
        case .weekly: "Week"
        case .monthly: "Month"
        }
    }

    var intervalDescription: String {
        switch self {
        case .daily: "day"
        case .weekly: "week"
        case .monthly: "month"
        }
    }

    func nextDate(after date: Date, calendar: Calendar = .current) -> Date {
        let component: Calendar.Component = switch self {
        case .daily: .day
        case .weekly: .weekOfYear
        case .monthly: .month
        }
        return calendar.date(byAdding: component, value: 1, to: date) ?? date
    }
}

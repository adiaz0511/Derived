import Foundation

nonisolated enum ScanTimestampText {
    static func string(
        scannedAt: Date,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        var style: Date.FormatStyle
        if calendar.isDate(scannedAt, inSameDayAs: now) {
            style = Date.FormatStyle(date: .omitted, time: .shortened)
        } else {
            style = Date.FormatStyle.dateTime
                .month(.abbreviated)
                .day()
                .hour()
                .minute()
            if calendar.component(.year, from: scannedAt) != calendar.component(.year, from: now) {
                style = style.year()
            }
        }
        style.calendar = calendar
        style.locale = locale
        style.timeZone = calendar.timeZone

        return "Scanned \(scannedAt.formatted(style))"
    }
}

import Foundation
import Testing
@testable import Derived

struct ScanTimestampTextTests {
    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func showsOnlyTimeForScanOnCurrentCalendarDay() throws {
        let scannedAt = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 8,
            hour: 13,
            minute: 57
        )))
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 8,
            hour: 22
        )))

        let text = ScanTimestampText.string(
            scannedAt: scannedAt,
            now: now,
            calendar: calendar,
            locale: locale
        )

        #expect(text.hasPrefix("Scanned 1:57"))
        #expect(text.hasSuffix("PM"))
    }

    @Test func showsDateAndTimeAfterCalendarDayChanges() throws {
        let scannedAt = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 7,
            hour: 23,
            minute: 45
        )))
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 8,
            hour: 0,
            minute: 5
        )))

        let text = ScanTimestampText.string(
            scannedAt: scannedAt,
            now: now,
            calendar: calendar,
            locale: locale
        )

        #expect(text.contains("Aug 7"))
        #expect(!text.contains("2026"))
        #expect(text.contains("11:45"))
        #expect(text.hasSuffix("PM"))
    }

    @Test func includesYearForScanFromEarlierYear() throws {
        let scannedAt = try #require(calendar.date(from: DateComponents(
            year: 2025,
            month: 12,
            day: 31,
            hour: 18
        )))
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 1,
            day: 1,
            hour: 8
        )))

        let text = ScanTimestampText.string(
            scannedAt: scannedAt,
            now: now,
            calendar: calendar,
            locale: locale
        )

        #expect(text.contains("2025"))
    }
}

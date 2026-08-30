import SwiftData
import XCTest
@testable import CouchToHour

@MainActor
final class ScheduleGeneratorTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func daysBetween(_ a: Date, _ b: Date) -> Int {
        calendar.dateComponents([.day], from: a, to: b).day ?? -1
    }

    func testFirstSessionIsTheStartDateAndCadenceHolds() {
        let start = date(2026, 1, 1)
        let slots = ScheduleGenerator.schedule(startingWeek: 1, startDate: start, calendar: calendar)

        XCTAssertEqual(slots.count, 18)
        XCTAssertEqual(slots.first, .init(week: 1, day: 1, date: start))

        for week in 1...6 {
            let days = slots.filter { $0.week == week }.sorted { $0.day < $1.day }
            XCTAssertEqual(days.count, 3)
            XCTAssertEqual(daysBetween(days[0].date, days[1].date), 2)   // one rest day
            XCTAssertEqual(daysBetween(days[1].date, days[2].date), 2)
            if week > 1 {
                let prevD1 = slots.first { $0.week == week - 1 && $0.day == 1 }!.date
                XCTAssertEqual(daysBetween(prevD1, days[0].date), 7)     // weeks 7 days apart
            }
        }
    }

    func testStartDateOnAnyWeekdayWorks() {
        for offset in 0..<7 {
            let start = calendar.date(byAdding: .day, value: offset, to: date(2026, 1, 1))!
            let slots = ScheduleGenerator.schedule(startingWeek: 1, startDate: start, calendar: calendar)
            XCTAssertEqual(slots.first?.date, calendar.startOfDay(for: start))
            XCTAssertEqual(slots.count, 18)
        }
    }

    func testStartingWeekSkipsEarlierWeeks() {
        let slots = ScheduleGenerator.schedule(startingWeek: 4, startDate: date(2026, 1, 1),
                                               calendar: calendar)
        XCTAssertEqual(slots.count, 9)
        XCTAssertEqual(Set(slots.map(\.week)), [4, 5, 6])
    }

    func testStartingMidWeekLandsChosenDayOnTheStartDate() {
        let slots = ScheduleGenerator.schedule(startingWeek: 2, startingDay: 3,
                                               startDate: date(2026, 1, 7), calendar: calendar)
        XCTAssertEqual(slots.first, .init(week: 2, day: 3, date: date(2026, 1, 7)))
        XCTAssertFalse(slots.contains { $0.week == 2 && $0.day < 3 })
        XCTAssertFalse(slots.contains { $0.week == 1 })
        // W3 D1 keeps the weekly cadence: 3 days after W2 D3 (offset 4 → 7).
        XCTAssertEqual(slots.first { $0.week == 3 && $0.day == 1 }?.date, date(2026, 1, 10))
    }

    func testLaterStartingWeekProducesNoSlotsForEarlierWeeks() {
        let slots = ScheduleGenerator.schedule(startingWeek: 3, startDate: date(2026, 1, 1),
                                               calendar: calendar)
        XCTAssertFalse(slots.contains { $0.week < 3 })
        XCTAssertEqual(Set(slots.map(\.week)), [3, 4, 5, 6])
        XCTAssertEqual(slots.count, 12)
    }
}

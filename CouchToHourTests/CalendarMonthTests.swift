import SwiftData
import XCTest
import UIWorkouts
@testable import CouchToHour

@MainActor
final class CalendarMonthTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func month(_ anchor: Date,
                       schedule: [ScheduleGenerator.Slot] = [],
                       completions: [CompletionRecord] = [],
                       today: Date) -> CalendarMonth {
        CalendarMonth.resolve(monthContaining: anchor, schedule: schedule,
                              completions: completions, today: today, calendar: calendar)
    }

    private func state(_ m: CalendarMonth, day: Int) -> WKDay.State? {
        m.days.first { $0.number == day }?.state
    }

    // MARK: Structure

    func testMonthShape() {
        // 2026-01-01 is a Thursday → Monday-first leading blanks = 3.
        let m = month(date(2026, 1, 10), today: date(2025, 12, 1))
        XCTAssertEqual(m.title, "January 2026")
        XCTAssertEqual(m.weekdaySymbols, ["M", "T", "W", "T", "F", "S", "S"])
        XCTAssertEqual(m.leadingBlanks, 3)
        XCTAssertEqual(m.days.count, 31)
        XCTAssertEqual(m.days.map(\.number), Array(1...31))
    }

    func testEmptyMonthIsAllDefault() {
        let m = month(date(2026, 3, 1), today: date(2026, 1, 1))
        XCTAssertTrue(m.days.allSatisfy { $0.state == .default })
    }

    // MARK: States

    func testTodayIsMarked() {
        let m = month(date(2026, 1, 15), today: date(2026, 1, 15))
        XCTAssertEqual(state(m, day: 15), .today)
        XCTAssertEqual(state(m, day: 14), .default)
    }

    func testCompletedDayGetsDone() {
        let completions = [CompletionRecord(date: date(2026, 1, 10), workoutDayKey: "W1D1", durationSeconds: 0)]
        let m = month(date(2026, 1, 1), completions: completions, today: date(2026, 1, 20))
        XCTAssertEqual(state(m, day: 10), .done)
    }

    func testDoneWinsOverToday() {
        let completions = [CompletionRecord(date: date(2026, 1, 15), workoutDayKey: "W1D1", durationSeconds: 0)]
        let m = month(date(2026, 1, 1), completions: completions, today: date(2026, 1, 15))
        XCTAssertEqual(state(m, day: 15), .done)
    }

    func testFutureScheduledDayIsMarked() {
        let anchor = date(2026, 2, 2)
        let schedule = ScheduleGenerator.schedule(startingWeek: 1, startDate: anchor, calendar: calendar)
        let firstDay = calendar.component(.day, from: schedule[0].date)

        let m = month(schedule[0].date, schedule: schedule, today: date(2026, 1, 15))
        XCTAssertEqual(state(m, day: firstDay), .scheduled)
        XCTAssertTrue(m.days.contains { $0.state == .scheduled })

        // No schedule (Free mode with nothing ahead) → nothing scheduled.
        let bare = month(schedule[0].date, schedule: [], today: date(2026, 1, 15))
        XCTAssertFalse(bare.days.contains { $0.state == .scheduled })
    }

    func testPastScheduledDayIsNotMarkedScheduled() {
        let anchor = date(2026, 2, 2)
        let schedule = ScheduleGenerator.schedule(startingWeek: 1, startDate: anchor, calendar: calendar)

        // "today" is after the whole February block → nothing in Feb is future.
        let m = month(anchor, schedule: schedule, today: date(2026, 4, 1))
        XCTAssertFalse(m.days.contains { $0.state == .scheduled })
    }
}

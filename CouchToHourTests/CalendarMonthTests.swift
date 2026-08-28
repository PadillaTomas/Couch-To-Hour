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
                       mode: TrainingMode = .free,
                       plan: WorkoutPlan? = nil,
                       completions: [CompletionRecord] = [],
                       today: Date) -> CalendarMonth {
        CalendarMonth.resolve(monthContaining: anchor, mode: mode, plan: plan,
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

    func test3DayShowsFutureScheduled() throws {
        let context = try seededContainer().mainContext
        let plan = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)
        let anchor = date(2026, 2, 2)
        ScheduleGenerator.apply(to: plan, startingWeek: 1, startWeekday: 2, anchor: anchor, calendar: calendar)

        let firstSlot = try XCTUnwrap(
            ScheduleGenerator.schedule(startingWeek: 1, startWeekday: 2, anchor: anchor, calendar: calendar).first
        )
        let firstDay = calendar.component(.day, from: firstSlot.date)

        let threeDay = month(firstSlot.date, mode: .threeDay, plan: plan, today: date(2026, 1, 15))
        XCTAssertEqual(state(threeDay, day: firstDay), .scheduled)
        XCTAssertTrue(threeDay.days.contains { $0.state == .scheduled })

        // Free mode ignores the schedule entirely.
        let free = month(firstSlot.date, mode: .free, plan: plan, today: date(2026, 1, 15))
        XCTAssertFalse(free.days.contains { $0.state == .scheduled })
    }

    func testPastScheduledDayIsNotMarkedScheduled() throws {
        let context = try seededContainer().mainContext
        let plan = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)
        let anchor = date(2026, 2, 2)
        ScheduleGenerator.apply(to: plan, startingWeek: 1, startWeekday: 2, anchor: anchor, calendar: calendar)

        // "today" is after the whole February block → nothing in Feb is future.
        let m = month(anchor, mode: .threeDay, plan: plan, today: date(2026, 4, 1))
        XCTAssertFalse(m.days.contains { $0.state == .scheduled })
    }
}

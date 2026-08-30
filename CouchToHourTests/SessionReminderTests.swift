import SwiftData
import XCTest
@testable import CouchToHour

@MainActor
final class SessionReminderTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }
    private func plan() throws -> WorkoutPlan {
        try XCTUnwrap(seededContainer().mainContext.fetch(FetchDescriptor<WorkoutPlan>()).first)
    }
    private func schedule(from start: Date) -> [ScheduleGenerator.Slot] {
        ScheduleGenerator.schedule(startingWeek: 1, startDate: start, calendar: calendar)
    }

    /// A schedule anchored today → one reminder per session still in the future,
    /// each firing at the configured time-of-day on its scheduled date.
    func testOneReminderPerUpcomingSessionAtTheConfiguredTime() throws {
        let plan = try plan()
        let start = date(2026, 1, 5)

        let reminders = SessionReminder.upcoming(
            schedule: schedule(from: start), plan: plan, completions: [], hour: 7, minute: 0,
            now: date(2026, 1, 4), calendar: calendar)

        XCTAssertEqual(reminders.count, 18)                      // full 6-week schedule
        XCTAssertEqual(reminders, reminders.sorted { $0.fireDate < $1.fireDate })
        let first = try XCTUnwrap(reminders.first)
        XCTAssertEqual(first.week, 1)
        XCTAssertEqual(first.day, 1)
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour, .minute],
                                               from: first.fireDate),
                       DateComponents(year: 2026, month: 1, day: 5, hour: 7, minute: 0))
        XCTAssertEqual(first.identifier, "cth.session.W1D1")
        XCTAssertTrue(first.identifier.hasPrefix(SessionReminder.identifierPrefix))
    }

    func testSessionsInThePastAreDropped() throws {
        let plan = try plan()

        // "Now" is Week 2ish — the first few sessions have already passed.
        let reminders = SessionReminder.upcoming(
            schedule: schedule(from: date(2026, 1, 5)), plan: plan, completions: [],
            now: date(2026, 1, 15), calendar: calendar)

        XCTAssertLessThan(reminders.count, 18)
        XCTAssertTrue(reminders.allSatisfy { $0.fireDate > date(2026, 1, 15) })
    }

    func testCompletedSessionsAreDropped() throws {
        let plan = try plan()
        let completions = [CompletionRecord(date: date(2026, 1, 5), workoutDayKey: "W1D1",
                                            durationSeconds: 1200)]

        let reminders = SessionReminder.upcoming(
            schedule: schedule(from: date(2026, 1, 5)), plan: plan, completions: completions,
            now: date(2026, 1, 4), calendar: calendar)

        XCTAssertEqual(reminders.count, 17)
        XCTAssertFalse(reminders.contains { $0.week == 1 && $0.day == 1 })
    }

    func testEmptyScheduleYieldsNothing() throws {
        XCTAssertTrue(SessionReminder.upcoming(schedule: [], plan: try plan(), completions: [],
                                               now: date(2026, 1, 1), calendar: calendar).isEmpty)
    }
}

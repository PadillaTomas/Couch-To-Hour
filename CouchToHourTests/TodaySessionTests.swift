import SwiftData
import XCTest
@testable import CouchToHour

@MainActor
final class TodaySessionTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func plan() throws -> WorkoutPlan {
        let context = try seededContainer().mainContext
        return try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)
    }

    private func done(_ keys: String...) -> [CompletionRecord] {
        keys.map { CompletionRecord(date: .now, workoutDayKey: $0, durationSeconds: 0) }
    }

    // MARK: Free

    func testFreeStartsAtWeek1Day1() throws {
        let s = TodaySession.resolve(mode: .free, plan: try plan(), startingWeek: 1, startDate: nil,
                                     completions: [], today: .now, calendar: calendar)
        XCTAssertEqual(s, .session(week: 1, day: 1, makeup: false))
    }

    func testFreeAdvancesPastCompletedDays() throws {
        let s = TodaySession.resolve(mode: .free, plan: try plan(), startingWeek: 1, startDate: nil,
                                     completions: done("W1D1"), today: .now, calendar: calendar)
        XCTAssertEqual(s, .session(week: 1, day: 2, makeup: false))
    }

    func testFreeHonoursStartingWeek() throws {
        let s = TodaySession.resolve(mode: .free, plan: try plan(), startingWeek: 3, startDate: nil,
                                     completions: [], today: .now, calendar: calendar)
        XCTAssertEqual(s, .session(week: 3, day: 1, makeup: false))
    }

    func testFreeAllDoneIsPlanComplete() throws {
        let all = (1...6).flatMap { w in (1...3).map { d in "W\(w)D\(d)" } }
        let s = TodaySession.resolve(mode: .free, plan: try plan(), startingWeek: 1, startDate: nil,
                                     completions: done(all: all), today: .now, calendar: calendar)
        XCTAssertEqual(s, .planComplete)
    }

    // MARK: 3-Day  (start Mon 2026-01-05 → W1 D1 Jan5 / D2 Jan7 / D3 Jan9)

    private func threeDay(today: Date, completions: [CompletionRecord]) throws -> TodaySession {
        TodaySession.resolve(mode: .threeDay, plan: try plan(), startingWeek: 1, startDate: date(2026, 1, 5),
                             completions: completions, today: today, calendar: calendar)
    }

    func testThreeDayOnScheduledDay() throws {
        XCTAssertEqual(try threeDay(today: date(2026, 1, 5), completions: []),
                       .session(week: 1, day: 1, makeup: false))
    }

    func testThreeDayRestDay() throws {
        XCTAssertEqual(try threeDay(today: date(2026, 1, 6), completions: done("W1D1")),
                       .rest)
    }

    func testThreeDayMissedWithASessionToday() throws {
        // Wed Jan 7: D1 (Mon) never done, D2 is today.
        XCTAssertEqual(try threeDay(today: date(2026, 1, 7), completions: []),
                       .missedChoice(missedWeek: 1, missedDay: 1, todayWeek: 1, todayDay: 2))
    }

    func testThreeDayMissedWithNoSessionToday() throws {
        // Thu Jan 8: D1 missed, nothing scheduled today → left with the make-up.
        XCTAssertEqual(try threeDay(today: date(2026, 1, 8), completions: done("W1D2")),
                       .session(week: 1, day: 1, makeup: true))
    }

    func testThreeDayPlanComplete() throws {
        let all = (1...6).flatMap { w in (1...3).map { d in "W\(w)D\(d)" } }
        XCTAssertEqual(try threeDay(today: date(2026, 3, 1), completions: done(all: all)),
                       .planComplete)
    }

    /// Restarting the plan from a session that was completed weeks ago still
    /// shows it today — the runner explicitly parked here.
    func testFutureStartDateShowsNotStartedYet() throws {
        let start = date(2026, 6, 1)
        for mode in [TrainingMode.free, .threeDay] {
            let s = TodaySession.resolve(mode: mode, plan: try plan(), startingWeek: 1,
                                         startDate: start, completions: [],
                                         today: date(2026, 5, 20), calendar: calendar)
            XCTAssertEqual(s, .notStartedYet(start), "\(mode)")
        }
        // Start date reached → normal flow.
        let started = TodaySession.resolve(mode: .free, plan: try plan(), startingWeek: 1,
                                           startDate: start, completions: [],
                                           today: date(2026, 6, 2), calendar: calendar)
        XCTAssertEqual(started, .session(week: 1, day: 1, makeup: false))
    }

    func testThreeDayShowsTheParkedSessionEvenIfPreviouslyDone() throws {
        let s = TodaySession.resolve(mode: .threeDay, plan: try plan(),
                                     startingWeek: 1, startingDay: 1,
                                     startDate: date(2026, 4, 6), completions: done("W1D1"),
                                     today: date(2026, 4, 6), calendar: calendar)
        XCTAssertEqual(s, .session(week: 1, day: 1, makeup: false))
    }
}

private extension TodaySessionTests {
    func done(all keys: [String]) -> [CompletionRecord] {
        keys.map { CompletionRecord(date: .now, workoutDayKey: $0, durationSeconds: 0) }
    }
}

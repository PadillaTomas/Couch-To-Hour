import SwiftData
import XCTest
@testable import CouchToHour

@MainActor
final class PlanStateTests: XCTestCase {

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
    private func done(_ keys: [String], on day: Date? = nil) -> [CompletionRecord] {
        keys.map { CompletionRecord(date: day ?? date(2026, 1, 1), workoutDayKey: $0, durationSeconds: 0) }
    }
    private func state(mode: TrainingMode, startingWeek: Int, startingDay: Int = 1,
                       startDate: Date?, planEpoch: Date = UserSettings.planEpochUnset,
                       completions: [CompletionRecord],
                       today: Date, plan: WorkoutPlan) -> PlanState {
        PlanState(mode: mode, startingWeek: startingWeek, startingDay: startingDay,
                  startDate: startDate, planEpoch: planEpoch, plan: plan,
                  completions: completions, today: today, calendar: calendar)
    }

    /// The bug this whole refactor is about: Today and the Calendar must resolve
    /// the *same* current session. Free, reconfigured to "start W2 D1 today"
    /// after an earlier pass through W1–W3.
    func testTodayAndCalendarAgreeOnTheCurrentSessionAfterAFreeReconfigure() throws {
        let earlier = (1...3).flatMap { w in (1...3).map { d in "W\(w)D\(d)" } }
        let s = state(mode: .free, startingWeek: 2, startingDay: 1,
                      startDate: date(2026, 4, 6), planEpoch: date(2026, 4, 6),
                      completions: done(earlier),
                      today: date(2026, 4, 6), plan: try plan())

        XCTAssertEqual(s.currentSession, .session(week: 2, day: 1, makeup: false))

        // Calendar's slot for today points at the same session — not "W4 D1".
        XCTAssertEqual(s.schedule.map { [$0.week, $0.day] }, [[2, 1]])
        let todayItems: [CalendarDayInfo.Item]
        if case .sessions(let i) = s.dayInfo(for: date(2026, 4, 6)) { todayItems = i } else { todayItems = [] }
        XCTAssertTrue(todayItems.contains { $0.week == 2 && $0.day == 1 && !$0.isDone })
    }

    func testThreeDayScheduleIsTheFullGrid() throws {
        let s = state(mode: .threeDay, startingWeek: 1,
                      startDate: date(2026, 1, 5), completions: [],
                      today: date(2026, 1, 1), plan: try plan())
        XCTAssertEqual(s.schedule.count, 18)
        XCTAssertEqual(s.schedule.first?.date, date(2026, 1, 5))
    }

    func testFreeScheduleIsEmptyOnceTheStartDateIsPast() throws {
        let s = state(mode: .free, startingWeek: 1,
                      startDate: date(2026, 1, 5), completions: [],
                      today: date(2026, 1, 20), plan: try plan())
        XCTAssertTrue(s.schedule.isEmpty)
        XCTAssertEqual(s.currentSession, .session(week: 1, day: 1, makeup: false))
    }

    func testMissingSingletonsYieldNilState() {
        XCTAssertNil(PlanState.from(settings: [], plans: [], completions: []))
    }

    // MARK: Plan epoch — a reconfigure starts a fresh instance

    /// Demo-style history from weeks ago must not pre-complete a plan the runner
    /// just reconfigured. It stays in `completions` (never deleted) but doesn't
    /// count toward `planCompletions`.
    func testCompletionsBeforeThePlanEpochDoNotCount() throws {
        let old = done((1...3).flatMap { w in (1...3).map { d in "W\(w)D\(d)" } },
                       on: date(2026, 3, 10))   // weeks before the reconfigure
        let s = state(mode: .free, startingWeek: 2, startingDay: 1,
                      startDate: date(2026, 4, 6), planEpoch: date(2026, 4, 6),
                      completions: old, today: date(2026, 4, 6), plan: try plan())

        XCTAssertEqual(s.completions.count, 9)         // history retained
        XCTAssertTrue(s.planCompletions.isEmpty)       // but none count for this plan
        XCTAssertEqual(s.currentSession, .session(week: 2, day: 1, makeup: false))
    }

    /// After marking the chosen start session done *today*, Today advances
    /// within the chosen plan (W2 D2) — not to the old demo position (W4 D1).
    func testProgressionFollowsTheChosenPlanNotTheOldHistory() throws {
        let old = done((1...3).flatMap { w in (1...3).map { d in "W\(w)D\(d)" } },
                       on: date(2026, 3, 10))
        var completions = old
        completions.append(contentsOf: done(["W2D1"], on: date(2026, 4, 6)))   // done under the new plan

        let s = state(mode: .free, startingWeek: 2, startingDay: 1,
                      startDate: date(2026, 4, 6), planEpoch: date(2026, 4, 6),
                      completions: completions, today: date(2026, 4, 6), plan: try plan())

        XCTAssertEqual(s.currentSession, .session(week: 2, day: 2, makeup: false))
    }

    /// Done dots stay forever, across a reconfigure — only progression is scoped.
    func testCalendarKeepsEveryDoneSessionAcrossAReconfigure() throws {
        let old = done(["W1D1"], on: date(2026, 3, 10))
        let s = state(mode: .free, startingWeek: 1, startingDay: 1,
                      startDate: date(2026, 4, 6), planEpoch: date(2026, 4, 6),
                      completions: old, today: date(2026, 4, 6), plan: try plan())

        let march = s.month(containing: date(2026, 3, 1))
        XCTAssertEqual(march.days.first { $0.number == 10 }?.state, .done)
        XCTAssertTrue(s.planCompletions.isEmpty, "…but it doesn't count toward the new plan")
    }

    /// A reconfigure regenerates the pending dots from the new schedule; the old
    /// schedule leaves nothing behind (it was never stored).
    func testPendingDotsComeOnlyFromTheCurrentSchedule() throws {
        let s = state(mode: .threeDay, startingWeek: 1,
                      startDate: date(2026, 4, 6), completions: [],
                      today: date(2026, 4, 6), plan: try plan())
        let april = s.month(containing: date(2026, 4, 6))
        let scheduledDays = april.days.filter { $0.state == .scheduled }.map(\.number)
        // W1 D2 is 2 days after the 4/6 start → the 8th; nothing before the start.
        XCTAssertTrue(scheduledDays.contains(8))
        XCTAssertFalse(scheduledDays.contains { $0 < 6 })
    }
}

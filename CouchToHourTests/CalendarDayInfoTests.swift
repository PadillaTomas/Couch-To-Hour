import SwiftData
import XCTest
@testable import CouchToHour

@MainActor
final class CalendarDayInfoTests: XCTestCase {

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
    /// W1 D1 Jan5 / D2 Jan7 / D3 Jan9 …
    private var schedule: [ScheduleGenerator.Slot] {
        ScheduleGenerator.schedule(startingWeek: 1, startDate: date(2026, 1, 5), calendar: calendar)
    }
    private func items(_ info: CalendarDayInfo) -> [CalendarDayInfo.Item] {
        if case .sessions(let i) = info { return i }
        return []
    }

    func testDoneDay() throws {
        let record = CompletionRecord(date: date(2026, 1, 5), workoutDayKey: "W1D1",
                                      durationSeconds: 1140, feltRating: 6)
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 5), plan: try plan(),
                                           schedule: schedule, completions: [record],
                                           today: date(2026, 1, 20), calendar: calendar)
        XCTAssertEqual(items(info), [
            .init(week: 1, day: 1,
                  groups: [.init(id: 0, runSeconds: 60, walkSeconds: 60, repeatCount: 10)],
                  status: .done(durationSeconds: 1140, feltRating: 6))
        ])
    }

    func testTwoSessionsOnOneDayBothShow() throws {
        let day = date(2026, 1, 12)
        let records = [
            CompletionRecord(date: day, workoutDayKey: "W1D3", durationSeconds: 900, feltRating: 5),
            CompletionRecord(date: day, workoutDayKey: "W2D1", durationSeconds: 1000, feltRating: 7),
        ]
        let info = CalendarDayInfo.resolve(date: day, plan: try plan(), schedule: schedule,
                                           completions: records, today: day, calendar: calendar)
        let result = items(info)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.map { [$0.week, $0.day] }, [[1, 3], [2, 1]])
        XCTAssertTrue(result.allSatisfy(\.isDone))
    }

    func testFutureScheduledDay() throws {
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 7), plan: try plan(),
                                           schedule: schedule, completions: [],
                                           today: date(2026, 1, 1), calendar: calendar)
        XCTAssertEqual(items(info), [
            .init(week: 1, day: 2,
                  groups: [.init(id: 0, runSeconds: 60, walkSeconds: 60, repeatCount: 1),
                           .init(id: 1, runSeconds: 120, walkSeconds: 60, repeatCount: 5)],
                  status: .scheduled(isToday: false))
        ])
    }

    func testScheduledDayThatIsToday() throws {
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 5), plan: try plan(),
                                           schedule: schedule, completions: [],
                                           today: date(2026, 1, 5), calendar: calendar)
        XCTAssertEqual(items(info).first?.status, .scheduled(isToday: true))
    }

    func testCompletionHidesTheScheduledDuplicate() throws {
        let record = CompletionRecord(date: date(2026, 1, 5), workoutDayKey: "W1D1", durationSeconds: 1)
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 5), plan: try plan(),
                                           schedule: schedule, completions: [record],
                                           today: date(2026, 1, 5), calendar: calendar)
        XCTAssertEqual(items(info).count, 1)
        XCTAssertTrue(items(info)[0].isDone)
    }

    func testEmptyDayIsRest() throws {
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 6), plan: try plan(),
                                           schedule: schedule, completions: [],
                                           today: date(2026, 1, 1), calendar: calendar)
        XCTAssertEqual(info, .rest)
    }

    func testNoScheduleMeansRestOnAnOtherwiseScheduledDay() throws {
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 7), plan: try plan(),
                                           schedule: [], completions: [],
                                           today: date(2026, 1, 1), calendar: calendar)
        XCTAssertEqual(info, .rest)
    }

    func testSingleSlotScheduleShowsThatSession() throws {
        // Free mode hands in at most one slot — the next session on its start date.
        let slot = [ScheduleGenerator.Slot(week: 1, day: 1, date: date(2026, 1, 10))]

        let onDay = CalendarDayInfo.resolve(date: date(2026, 1, 10), plan: try plan(),
                                            schedule: slot, completions: [],
                                            today: date(2026, 1, 1), calendar: calendar)
        XCTAssertEqual(items(onDay).first?.status, .scheduled(isToday: false))
        XCTAssertEqual(items(onDay).first.map { [$0.week, $0.day] }, [1, 1])

        let otherDay = CalendarDayInfo.resolve(date: date(2026, 1, 11), plan: try plan(),
                                               schedule: slot, completions: [],
                                               today: date(2026, 1, 1), calendar: calendar)
        XCTAssertEqual(otherDay, .rest)
    }
}

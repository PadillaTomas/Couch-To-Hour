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
    private func scheduledPlan() throws -> WorkoutPlan {
        let context = try seededContainer().mainContext
        let plan = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)
        ScheduleGenerator.apply(to: plan, startingWeek: 1, startDate: date(2026, 1, 5), calendar: calendar)
        return plan
    }
    private func items(_ info: CalendarDayInfo) -> [CalendarDayInfo.Item] {
        if case .sessions(let i) = info { return i }
        return []
    }

    func testDoneDay() throws {
        let plan = try scheduledPlan()
        let record = CompletionRecord(date: date(2026, 1, 5), workoutDayKey: "W1D1",
                                      durationSeconds: 1140, feltRating: 6)
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 5), mode: .threeDay, plan: plan,
                                           completions: [record], today: date(2026, 1, 20),
                                           calendar: calendar)
        XCTAssertEqual(items(info), [
            .init(week: 1, day: 1,
                  groups: [.init(id: 0, runSeconds: 60, walkSeconds: 60, repeatCount: 10)],
                  status: .done(durationSeconds: 1140, feltRating: 6))
        ])
    }

    func testTwoSessionsOnOneDayBothShow() throws {
        let plan = try scheduledPlan()
        let day = date(2026, 1, 12)
        let records = [
            CompletionRecord(date: day, workoutDayKey: "W1D3", durationSeconds: 900, feltRating: 5),
            CompletionRecord(date: day, workoutDayKey: "W2D1", durationSeconds: 1000, feltRating: 7),
        ]
        let info = CalendarDayInfo.resolve(date: day, mode: .threeDay, plan: plan,
                                           completions: records, today: day, calendar: calendar)
        let result = items(info)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.map { [$0.week, $0.day] }, [[1, 3], [2, 1]])
        XCTAssertTrue(result.allSatisfy(\.isDone))
    }

    func testFutureScheduledDay() throws {
        let plan = try scheduledPlan()   // W1 D1 Jan5 / D2 Jan7 / D3 Jan9
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 7), mode: .threeDay, plan: plan,
                                           completions: [], today: date(2026, 1, 1), calendar: calendar)
        XCTAssertEqual(items(info), [
            .init(week: 1, day: 2,
                  groups: [.init(id: 0, runSeconds: 60, walkSeconds: 60, repeatCount: 1),
                           .init(id: 1, runSeconds: 120, walkSeconds: 60, repeatCount: 5)],
                  status: .scheduled(isToday: false))
        ])
    }

    func testScheduledDayThatIsToday() throws {
        let plan = try scheduledPlan()
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 5), mode: .threeDay, plan: plan,
                                           completions: [], today: date(2026, 1, 5), calendar: calendar)
        XCTAssertEqual(items(info).first?.status, .scheduled(isToday: true))
    }

    func testCompletionHidesTheScheduledDuplicate() throws {
        let plan = try scheduledPlan()
        let record = CompletionRecord(date: date(2026, 1, 5), workoutDayKey: "W1D1", durationSeconds: 1)
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 5), mode: .threeDay, plan: plan,
                                           completions: [record], today: date(2026, 1, 5), calendar: calendar)
        XCTAssertEqual(items(info).count, 1)
        XCTAssertTrue(items(info)[0].isDone)
    }

    func testEmptyDayIsRest() throws {
        let plan = try scheduledPlan()
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 6), mode: .threeDay, plan: plan,
                                           completions: [], today: date(2026, 1, 1), calendar: calendar)
        XCTAssertEqual(info, .rest)
    }

    func testFreeModeIgnoresSchedule() throws {
        let plan = try scheduledPlan()
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 7), mode: .free, plan: plan,
                                           completions: [], today: date(2026, 1, 1), calendar: calendar)
        XCTAssertEqual(info, .rest)
    }

    func testFreeModeShowsTheFirstRunDate() throws {
        let plan = try scheduledPlan()
        let first = (date: date(2026, 1, 10), week: 1, day: 1)

        let onDay = CalendarDayInfo.resolve(date: date(2026, 1, 10), mode: .free, plan: plan,
                                            completions: [], today: date(2026, 1, 1),
                                            freeFirstSession: first, calendar: calendar)
        XCTAssertEqual(items(onDay).first?.status, .scheduled(isToday: false))
        XCTAssertEqual(items(onDay).first.map { [$0.week, $0.day] }, [1, 1])

        let otherDay = CalendarDayInfo.resolve(date: date(2026, 1, 11), mode: .free, plan: plan,
                                               completions: [], today: date(2026, 1, 1),
                                               freeFirstSession: first, calendar: calendar)
        XCTAssertEqual(otherDay, .rest)
    }
}

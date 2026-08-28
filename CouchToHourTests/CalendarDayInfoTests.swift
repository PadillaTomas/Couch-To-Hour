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
        ScheduleGenerator.apply(to: plan, startingWeek: 1, startWeekday: 2,
                                anchor: date(2026, 1, 5), calendar: calendar)   // Mon 5 Jan
        return plan
    }

    func testDoneDay() throws {
        let plan = try scheduledPlan()
        let record = CompletionRecord(date: date(2026, 1, 5), workoutDayKey: "W1D1",
                                      durationSeconds: 1140, feltRating: 6)
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 5), mode: .threeDay, plan: plan,
                                           completions: [record], today: date(2026, 1, 20),
                                           calendar: calendar)
        XCTAssertEqual(info, .done(
            week: 1, day: 1,
            groups: [.init(id: 0, runSeconds: 60, walkSeconds: 60, repeatCount: 10)],
            durationSeconds: 1140, feltRating: 6
        ))
    }

    func testFutureScheduledDay() throws {
        let plan = try scheduledPlan()   // W1 D1 Jan5 / D2 Jan7 / D3 Jan9
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 7), mode: .threeDay, plan: plan,
                                           completions: [], today: date(2026, 1, 1),
                                           calendar: calendar)
        XCTAssertEqual(info, .scheduled(
            week: 1, day: 2,
            groups: [.init(id: 0, runSeconds: 60, walkSeconds: 60, repeatCount: 1),
                     .init(id: 1, runSeconds: 120, walkSeconds: 60, repeatCount: 5)],
            isToday: false
        ))
    }

    func testScheduledDayThatIsToday() throws {
        let plan = try scheduledPlan()
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 5), mode: .threeDay, plan: plan,
                                           completions: [], today: date(2026, 1, 5),
                                           calendar: calendar)
        if case .scheduled(_, _, _, let isToday) = info {
            XCTAssertTrue(isToday)
        } else {
            XCTFail("expected .scheduled, got \(info)")
        }
    }

    func testEmptyDayIsRest() throws {
        let plan = try scheduledPlan()
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 6), mode: .threeDay, plan: plan,
                                           completions: [], today: date(2026, 1, 1),
                                           calendar: calendar)
        XCTAssertEqual(info, .rest)
    }

    func testFreeModeIgnoresSchedule() throws {
        let plan = try scheduledPlan()   // schedule is applied, but Free ignores it
        let info = CalendarDayInfo.resolve(date: date(2026, 1, 7), mode: .free, plan: plan,
                                           completions: [], today: date(2026, 1, 1),
                                           calendar: calendar)
        XCTAssertEqual(info, .rest)
    }
}

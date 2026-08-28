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

    /// 2026-01-01 is a Thursday (weekday 5).
    private let anchor = DateComponents(year: 2026, month: 1, day: 1)

    func testGeneratesForEveryStartWeekday() {
        let anchorDate = calendar.date(from: anchor)!

        for weekday in 1...7 {
            let slots = ScheduleGenerator.schedule(startingWeek: 1,
                                                   startWeekday: weekday,
                                                   anchor: anchorDate,
                                                   calendar: calendar)

            XCTAssertEqual(slots.count, 18, "weekday \(weekday)")

            // Every D1 lands on the chosen weekday.
            let d1s = slots.filter { $0.day == 1 }.sorted { $0.week < $1.week }
            for slot in d1s {
                XCTAssertEqual(calendar.component(.weekday, from: slot.date), weekday,
                               "week \(slot.week) D1, weekday \(weekday)")
            }

            // First D1 is within the coming week and not before the anchor.
            let firstD1 = try! XCTUnwrap(d1s.first).date
            XCTAssertGreaterThanOrEqual(firstD1, calendar.startOfDay(for: anchorDate))
            XCTAssertLessThan(firstD1, calendar.date(byAdding: .day, value: 7, to: anchorDate)!)

            // One rest day between sessions; each week's D1 is 7 days on.
            for week in 1...6 {
                let days = slots.filter { $0.week == week }.sorted { $0.day < $1.day }
                XCTAssertEqual(days.count, 3)
                XCTAssertEqual(daysBetween(days[0].date, days[1].date), 2)
                XCTAssertEqual(daysBetween(days[1].date, days[2].date), 2)
                if week > 1 {
                    let prevD1 = slots.first { $0.week == week - 1 && $0.day == 1 }!.date
                    XCTAssertEqual(daysBetween(prevD1, days[0].date), 7)
                }
            }
        }
    }

    func testAnchorOnStartWeekdaySchedulesThatSameDay() {
        // Anchor is Thursday = weekday 5.
        let slots = ScheduleGenerator.schedule(startingWeek: 1, startWeekday: 5,
                                               anchor: calendar.date(from: anchor)!,
                                               calendar: calendar)
        XCTAssertEqual(slots.first?.date, date(2026, 1, 1))
    }

    func testStartingWeekSkipsEarlierWeeks() {
        let slots = ScheduleGenerator.schedule(startingWeek: 4, startWeekday: 2,
                                               anchor: calendar.date(from: anchor)!,
                                               calendar: calendar)
        XCTAssertEqual(slots.count, 9)
        XCTAssertEqual(Set(slots.map(\.week)), [4, 5, 6])
    }

    func testApplyWritesAndClearsScheduledDates() throws {
        let context = try TestContainer.seeded().mainContext
        let plan = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)

        ScheduleGenerator.apply(to: plan, startingWeek: 1, startWeekday: 2,
                                anchor: calendar.date(from: anchor)!, calendar: calendar)
        let scheduled = plan.orderedWeeks.flatMap(\.orderedDays)
        XCTAssertTrue(scheduled.allSatisfy { $0.scheduledDate != nil })

        ScheduleGenerator.clearSchedule(for: plan)
        XCTAssertTrue(scheduled.allSatisfy { $0.scheduledDate == nil })
    }

    func testApplyWithLaterStartingWeekClearsEarlierWeeks() throws {
        let context = try TestContainer.seeded().mainContext
        let plan = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)

        ScheduleGenerator.apply(to: plan, startingWeek: 3, startWeekday: 2,
                                anchor: calendar.date(from: anchor)!, calendar: calendar)

        for week in plan.orderedWeeks {
            let expectDates = week.number >= 3
            XCTAssertEqual(week.orderedDays.allSatisfy { ($0.scheduledDate != nil) == expectDates }, true,
                           "week \(week.number)")
        }
    }

    private func daysBetween(_ a: Date, _ b: Date) -> Int {
        calendar.dateComponents([.day], from: a, to: b).day ?? -1
    }
}

import SwiftData
import XCTest
@testable import CouchToHour

@MainActor
final class OnboardingCompletionTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func context() throws -> ModelContext {
        try seededContainer().mainContext
    }

    private func plan(in context: ModelContext) throws -> WorkoutPlan {
        try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)
    }

    private func settings(in context: ModelContext) throws -> UserSettings {
        try XCTUnwrap(context.fetch(FetchDescriptor<UserSettings>()).first)
    }

    /// Monday-first picker index → Calendar weekday (1 Sun … 7 Sat).
    func testWeekdayMapping() {
        let map = (0...6).map { OnboardingCompletion.calendarWeekday(fromMondayFirstIndex: $0) }
        XCTAssertEqual(map, [2, 3, 4, 5, 6, 7, 1])
    }

    func testFinishThreeDayPersistsChoicesAndPopulatesSchedule() throws {
        let context = try context()
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

        OnboardingCompletion.finish(
            .init(mode: .threeDay, startingWeek: 1, startWeekdayIndex: 0),
            now: now, in: context, calendar: calendar
        )

        let settings = try settings(in: context)
        XCTAssertEqual(settings.mode, .threeDay)
        XCTAssertEqual(settings.startingWeek, 1)
        XCTAssertEqual(settings.startWeekday, 2)          // Monday
        XCTAssertEqual(settings.startDate, now)
        XCTAssertTrue(settings.onboardingCompleted)

        let days = try plan(in: context).orderedWeeks.flatMap(\.orderedDays)
        XCTAssertTrue(days.allSatisfy { $0.scheduledDate != nil })
    }

    func testFinishThreeDayWithLaterStartingWeekLeavesEarlierWeeksUnscheduled() throws {
        let context = try context()

        OnboardingCompletion.finish(
            .init(mode: .threeDay, startingWeek: 3, startWeekdayIndex: 2),
            now: .now, in: context, calendar: calendar
        )

        for week in try plan(in: context).orderedWeeks {
            let expectDates = week.number >= 3
            XCTAssertTrue(week.orderedDays.allSatisfy { ($0.scheduledDate != nil) == expectDates },
                          "week \(week.number)")
        }
    }

    func testFinishFreeModeClearsAnySchedule() throws {
        let context = try context()

        // Populate a schedule first, then switch to Free.
        OnboardingCompletion.finish(.init(mode: .threeDay, startingWeek: 1, startWeekdayIndex: 0),
                                    now: .now, in: context, calendar: calendar)
        OnboardingCompletion.finish(.init(mode: .free, startingWeek: 1, startWeekdayIndex: 0),
                                    now: .now, in: context, calendar: calendar)

        let settings = try settings(in: context)
        XCTAssertEqual(settings.mode, .free)
        XCTAssertNil(settings.startDate)
        XCTAssertTrue(settings.onboardingCompleted)

        let days = try plan(in: context).orderedWeeks.flatMap(\.orderedDays)
        XCTAssertTrue(days.allSatisfy { $0.scheduledDate == nil })
    }

    func testGateAndChoicesSurviveAStoreReload() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cth-onboarding-\(UUID().uuidString).store")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let config = ModelConfiguration(url: url)

        let first = try ModelContainer(for: CouchToHourSchema.schema, configurations: config)
        PlanSeed.seed(into: first.mainContext)
        OnboardingCompletion.finish(.init(mode: .free, startingWeek: 4, startWeekdayIndex: 0),
                                    now: .now, in: first.mainContext, calendar: calendar)

        let relaunch = try ModelContainer(for: CouchToHourSchema.schema, configurations: config)
        let reloaded = try XCTUnwrap(relaunch.mainContext.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertTrue(reloaded.onboardingCompleted)
        XCTAssertEqual(reloaded.mode, .free)
        XCTAssertEqual(reloaded.startingWeek, 4)
    }
}

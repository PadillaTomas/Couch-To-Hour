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
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }
    private func context() throws -> ModelContext { try seededContainer().mainContext }
    private func plan(in context: ModelContext) throws -> WorkoutPlan {
        try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)
    }
    private func settings(in context: ModelContext) throws -> UserSettings {
        try XCTUnwrap(context.fetch(FetchDescriptor<UserSettings>()).first)
    }

    func testApplyThreeDayPersistsSetupAndPopulatesSchedule() throws {
        let context = try context()
        let start = date(2026, 1, 1)   // Thursday

        OnboardingCompletion.apply(PlanSetup(mode: .threeDay, startingWeek: 1, startDate: start),
                                   in: context, calendar: calendar)

        let settings = try settings(in: context)
        XCTAssertEqual(settings.mode, .threeDay)
        XCTAssertEqual(settings.startingWeek, 1)
        XCTAssertEqual(settings.startDate, start)
        XCTAssertEqual(settings.startWeekday, 5)          // derived from the start date (Thu)
        XCTAssertTrue(settings.onboardingCompleted)

        XCTAssertEqual(try plan(in: context).day(week: 1, day: 1)?.scheduledDate, start)
        XCTAssertTrue(try plan(in: context).orderedWeeks.flatMap(\.orderedDays)
            .allSatisfy { $0.scheduledDate != nil })
    }

    func testApplyThreeDayDefaultsStartDateToNow() throws {
        let context = try context()
        let now = date(2026, 5, 4)
        OnboardingCompletion.apply(PlanSetup(mode: .threeDay, startingWeek: 1),
                                   now: now, in: context, calendar: calendar)
        XCTAssertEqual(try settings(in: context).startDate, now)
    }

    func testApplyThreeDayWithLaterStartingWeekLeavesEarlierWeeksUnscheduled() throws {
        let context = try context()
        OnboardingCompletion.apply(PlanSetup(mode: .threeDay, startingWeek: 3, startDate: date(2026, 1, 1)),
                                   in: context, calendar: calendar)

        for week in try plan(in: context).orderedWeeks {
            let expectDates = week.number >= 3
            XCTAssertTrue(week.orderedDays.allSatisfy { ($0.scheduledDate != nil) == expectDates },
                          "week \(week.number)")
        }
    }

    func testApplyFreeClearsAnyScheduleAndStoresOptionalDate() throws {
        let context = try context()
        OnboardingCompletion.apply(PlanSetup(mode: .threeDay, startingWeek: 1, startDate: date(2026, 1, 1)),
                                   in: context, calendar: calendar)
        OnboardingCompletion.apply(PlanSetup(mode: .free, startingWeek: 1, startDate: date(2026, 2, 9)),
                                   in: context, calendar: calendar)

        let settings = try settings(in: context)
        XCTAssertEqual(settings.mode, .free)
        XCTAssertEqual(settings.startDate, date(2026, 2, 9))
        XCTAssertTrue(try plan(in: context).orderedWeeks.flatMap(\.orderedDays)
            .allSatisfy { $0.scheduledDate == nil })
    }

    func testGateAndSetupSurviveAStoreReload() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cth-onboarding-\(UUID().uuidString).store")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let config = ModelConfiguration(url: url)

        let first = try ModelContainer(for: CouchToHourSchema.schema, configurations: config)
        PlanSeed.seed(into: first.mainContext)
        OnboardingCompletion.apply(PlanSetup(mode: .free, startingWeek: 4, startingDay: 2),
                                   now: .now, in: first.mainContext, calendar: calendar)

        let relaunch = try ModelContainer(for: CouchToHourSchema.schema, configurations: config)
        let reloaded = try XCTUnwrap(relaunch.mainContext.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertTrue(reloaded.onboardingCompleted)
        XCTAssertEqual(reloaded.mode, .free)
        XCTAssertEqual(reloaded.startingWeek, 4)
        XCTAssertEqual(reloaded.startingDay, 2)
    }
}

import SwiftData
import XCTest
@testable import CouchToHour

@MainActor
final class PlanSetupTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }
    private func fixture() throws -> (UserSettings, WorkoutPlan, ModelContext) {
        let context = try seededContainer().mainContext
        return (UserSettings.current(in: context),
                try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first),
                context)
    }

    // MARK: FreeProgression startingDay

    func testFreeProgressionSkipsDaysBeforeStartingDay() throws {
        let (_, plan, _) = try fixture()
        let next = FreeProgression.nextDay(in: plan, startingWeek: 2, startingDay: 3) { _ in false }
        XCTAssertEqual(next?.week?.number, 2)
        XCTAssertEqual(next?.number, 3)
    }

    // MARK: PlanPosition

    func testPlanPositionIsFirstNotDoneAtOrAfterStart() throws {
        let (_, plan, _) = try fixture()
        let done = [CompletionRecord(date: .now, workoutDayKey: "W1D1", durationSeconds: 1),
                    CompletionRecord(date: .now, workoutDayKey: "W1D2", durationSeconds: 1)]
        XCTAssertEqual(PlanPosition.next(in: plan, startingWeek: 1, startingDay: 1,
                                         completions: done).map { [$0.week, $0.day] }, [1, 3])
        XCTAssertNil(PlanPosition.next(in: plan, startingWeek: 6, startingDay: 4,
                                       completions: []))   // past the end
    }

    // MARK: OnboardingCompletion.apply

    func testApplyFromSettingsDoesNotFlipTheOnboardingGate() throws {
        let (settings, _, context) = try fixture()
        settings.onboardingCompleted = true

        OnboardingCompletion.apply(PlanSetup(mode: .free, startingWeek: 2, startingDay: 3),
                                   markOnboardingComplete: false, in: context, calendar: calendar)

        XCTAssertEqual(settings.mode, .free)
        XCTAssertEqual(settings.startingWeek, 2)
        XCTAssertEqual(settings.startingDay, 3)
        XCTAssertTrue(settings.onboardingCompleted)   // untouched
    }

    func testApplyThreeDayFromSettingsStartsTheChosenSessionOnTheStartDate() throws {
        let (settings, plan, context) = try fixture()
        // Simulate history + a mid-plan reconfigure to "start W2 · D2 today".
        settings.onboardingCompleted = true
        OnboardingCompletion.apply(
            PlanSetup(mode: .threeDay, startingWeek: 2, startingDay: 2, startDate: date(2026, 4, 6)),
            markOnboardingComplete: false, in: context, calendar: calendar)

        XCTAssertNil(plan.day(week: 2, day: 1)?.scheduledDate)                 // dropped
        XCTAssertEqual(plan.day(week: 2, day: 2)?.scheduledDate, date(2026, 4, 6))  // today
        // TodaySession should hand back that very session, not "rest".
        let session = TodaySession.resolve(mode: .threeDay, plan: plan,
                                           startingWeek: 2, startingDay: 2,
                                           startDate: date(2026, 4, 6), completions: [],
                                           today: date(2026, 4, 6), calendar: calendar)
        XCTAssertEqual(session, .session(week: 2, day: 2, makeup: false))
    }

    func testApplyFreeStoresTheOptionalFirstRunDate() throws {
        let (settings, _, context) = try fixture()
        let first = date(2026, 3, 2)

        OnboardingCompletion.apply(PlanSetup(mode: .free, startingWeek: 1, startDate: first),
                                   in: context, calendar: calendar)
        XCTAssertEqual(settings.startDate, first)

        OnboardingCompletion.apply(PlanSetup(mode: .free, startingWeek: 1, startDate: nil),
                                   in: context, calendar: calendar)
        XCTAssertNil(settings.startDate)
    }
}

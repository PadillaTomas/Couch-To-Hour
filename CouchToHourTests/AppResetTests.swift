import SwiftData
import XCTest
import UIWorkouts
@testable import CouchToHour

@MainActor
final class AppResetTests: XCTestCase {

    func testFullResetClearsProgressAndReArmsOnboarding() throws {
        let context = try seededContainer().mainContext
        let plan = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)

        // Get into a fully set-up state: onboarded, scheduled, one session done.
        OnboardingCompletion.apply(PlanSetup(mode: .threeDay, startingWeek: 1),
                                   now: .now, in: context)
        let settings = try XCTUnwrap(context.fetch(FetchDescriptor<UserSettings>()).first)
        settings.themeMode = .dark
        DoneDetection.markComplete(plan.orderedWeeks[0].orderedDays[0], on: .now, in: context)
        try context.save()

        AppReset.performFullReset(in: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CompletionRecord>()), 0)
        XCTAssertTrue(plan.orderedWeeks.flatMap(\.orderedDays).allSatisfy { $0.scheduledDate == nil })

        let reset = try XCTUnwrap(context.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertFalse(reset.onboardingCompleted)
        XCTAssertEqual(reset.mode, .threeDay)
        XCTAssertEqual(reset.startingWeek, 1)
        XCTAssertNil(reset.startDate)
        XCTAssertEqual(reset.themeMode, .dark, "theme is not workout data — it should survive a reset")

        // Plan itself is untouched.
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutDay>()), 18)
    }
}

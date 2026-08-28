#if DEBUG
import SwiftData
import XCTest
@testable import CouchToHour

@MainActor
final class DemoDataTests: XCTestCase {

    func testLoadThreeDayPopulatesPastAndFuture() throws {
        let context = try seededContainer().mainContext
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 28))!

        DemoData.loadThreeDay(into: context, now: now)

        let settings = try XCTUnwrap(context.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertEqual(settings.mode, .threeDay)
        XCTAssertTrue(settings.onboardingCompleted)
        XCTAssertNotNil(settings.startDate)

        let completions = try context.fetch(FetchDescriptor<CompletionRecord>())
        XCTAssertFalse(completions.isEmpty, "expected past sessions to be completed")
        XCTAssertTrue(completions.allSatisfy { $0.date < now }, "completions must be in the past")
        XCTAssertTrue(completions.allSatisfy { ($0.feltRating ?? 0) >= 1 })

        let plan = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)
        let scheduled = plan.orderedWeeks.flatMap(\.orderedDays).compactMap(\.scheduledDate)
        XCTAssertEqual(scheduled.count, 18, "the whole plan should be scheduled")
        XCTAssertTrue(scheduled.contains { $0 > now }, "some sessions must be upcoming")
    }

    func testLoadThreeDayIsIdempotent() throws {
        let context = try seededContainer().mainContext
        DemoData.loadThreeDay(into: context)
        let first = try context.fetchCount(FetchDescriptor<CompletionRecord>())
        DemoData.loadThreeDay(into: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CompletionRecord>()), first)
    }
}
#endif

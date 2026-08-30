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

        // The demo anchors the schedule ~2.5 weeks back, so some sessions are
        // still ahead of `now`. The schedule is derived from settings, not stored.
        let anchor = try XCTUnwrap(settings.startDate)
        let schedule = ScheduleGenerator.schedule(startingWeek: 1, startDate: anchor)
        XCTAssertEqual(schedule.count, 18, "the whole plan should be scheduled")
        XCTAssertTrue(schedule.contains { $0.date > now }, "some sessions must be upcoming")
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

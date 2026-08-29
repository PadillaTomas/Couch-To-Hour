import SwiftData
import XCTest
@testable import CouchToHour

@MainActor
final class DoneDetectionTests: XCTestCase {

    private func firstDay() throws -> (WorkoutDay, ModelContext) {
        let context = try seededContainer().mainContext
        let plan = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)
        return (plan.orderedWeeks[0].orderedDays[0], context)
    }

    func testMarkCompleteInsertsOneRecord() throws {
        let (day, context) = try firstDay()

        let record = DoneDetection.markComplete(day, on: .now, in: context)
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.workoutDayKey, "W1D1")
        XCTAssertNil(record?.feltRating)
        // Defaulted duration is the played plan total: (R1/W1)×10 with the
        // trailing recovery walk trimmed → 10×60 run + 9×60 walk = 1140s.
        XCTAssertEqual(record?.durationSeconds, 1140)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CompletionRecord>()), 1)
    }

    func testMarkCompleteIsIdempotentWithinADay() throws {
        let (day, context) = try firstDay()

        XCTAssertNotNil(DoneDetection.markComplete(day, on: .now, in: context))
        try context.save()
        XCTAssertNil(DoneDetection.markComplete(day, on: .now, durationSeconds: 999, in: context))

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CompletionRecord>()), 1)
    }

    func testMarkCompleteOnAnotherDayLogsAgain() throws {
        let (day, context) = try firstDay()
        let today = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let nextWeek = today.addingTimeInterval(7 * 24 * 3600)

        XCTAssertNotNil(DoneDetection.markComplete(day, on: today, in: context))
        try context.save()
        XCTAssertNotNil(DoneDetection.markComplete(day, on: nextWeek, in: context))   // re-done later

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CompletionRecord>()), 2)
    }

    func testIsCompleteChecksByCoordinate() throws {
        let (day, context) = try firstDay()
        DoneDetection.markComplete(day, on: .now, in: context)
        let records = try context.fetch(FetchDescriptor<CompletionRecord>())

        XCTAssertTrue(DoneDetection.isComplete(week: 1, day: 1, among: records))
        XCTAssertTrue(DoneDetection.isComplete(day, among: records))
        XCTAssertFalse(DoneDetection.isComplete(week: 1, day: 2, among: records))
    }
}

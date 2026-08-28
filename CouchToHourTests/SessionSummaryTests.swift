import SwiftData
import XCTest
@testable import CouchToHour

@MainActor
final class SessionSummaryTests: XCTestCase {

    private func plan() throws -> WorkoutPlan {
        let context = try seededContainer().mainContext
        return try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)
    }

    func testSummaryForRepeatedBlock() throws {
        let day = try XCTUnwrap(plan().day(week: 1, day: 1))
        XCTAssertEqual(SessionPlan.summary(of: day), "1 min run / 1 min walk ×10")
    }

    func testSummaryForTwoBlocks() throws {
        let day = try XCTUnwrap(plan().day(week: 1, day: 2))
        XCTAssertEqual(SessionPlan.summary(of: day),
                       "1 min run / 1 min walk, then 2 min run / 1 min walk ×5")
    }

    func testSummaryForContinuousRun() throws {
        let day = try XCTUnwrap(plan().day(week: 6, day: 3))
        XCTAssertEqual(SessionPlan.summary(of: day), "50 min run")
    }

    func testGroupLine() throws {
        let plan = try plan()
        XCTAssertEqual(SessionPlan.groups(of: try XCTUnwrap(plan.day(week: 1, day: 1))).map(\.line),
                       ["Run 1:00    Walk 1:00    ×10"])
        XCTAssertEqual(SessionPlan.groups(of: try XCTUnwrap(plan.day(week: 6, day: 3))).map(\.line),
                       ["Run 50:00"])
        XCTAssertEqual(SessionPlan.groups(of: try XCTUnwrap(plan.day(week: 5, day: 2))).map(\.line),
                       ["Run 10:00    Walk 1:00",
                        "Run 25:00    Walk 1:00",
                        "Run 10:00    Walk 1:00"])
    }

    func testWorkoutCoordinateParsing() {
        let record = CompletionRecord(date: .now, workoutDayKey: "W2D1", durationSeconds: 0)
        let coord = record.workoutCoordinate
        XCTAssertEqual(coord?.week, 2)
        XCTAssertEqual(coord?.day, 1)

        let bad = CompletionRecord(date: .now, workoutDayKey: "nope", durationSeconds: 0)
        XCTAssertNil(bad.workoutCoordinate)
    }
}

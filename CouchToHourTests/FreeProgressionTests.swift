import SwiftData
import XCTest
@testable import CouchToHour

@MainActor
final class FreeProgressionTests: XCTestCase {

    private func makePlan() throws -> (WorkoutPlan, ModelContext) {
        let context = try seededContainer().mainContext
        let plan = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)
        return (plan, context)
    }

    func testStartsAtWeek1Day1WhenNothingDone() throws {
        let (plan, _) = try makePlan()
        let next = FreeProgression.nextDay(in: plan, startingWeek: 1) { _ in false }
        XCTAssertEqual(next?.week?.number, 1)
        XCTAssertEqual(next?.number, 1)
    }

    func testAdvancesThroughDaysInOrder() throws {
        let (plan, _) = try makePlan()
        var done: Set<String> = []

        let expected = (1...6).flatMap { w in (1...3).map { d in (w, d) } }
        for (week, day) in expected {
            let next = FreeProgression.nextDay(in: plan, startingWeek: 1) { done.contains($0.completionKey) }
            XCTAssertEqual(next?.week?.number, week)
            XCTAssertEqual(next?.number, day)
            done.insert(WorkoutDay.completionKey(week: week, day: day))
        }

        XCTAssertNil(FreeProgression.nextDay(in: plan, startingWeek: 1) { done.contains($0.completionKey) })
    }

    func testHonoursStartingWeek() throws {
        let (plan, _) = try makePlan()
        let next = FreeProgression.nextDay(in: plan, startingWeek: 3) { _ in false }
        XCTAssertEqual(next?.week?.number, 3)
        XCTAssertEqual(next?.number, 1)
    }

    /// A gap earlier in the plan is still the next thing to do.
    func testReturnsEarliestIncompleteDayNotTheLatest() throws {
        let (plan, _) = try makePlan()
        let done: Set<String> = [
            WorkoutDay.completionKey(week: 1, day: 1),
            WorkoutDay.completionKey(week: 1, day: 3),
        ]
        let next = FreeProgression.nextDay(in: plan, startingWeek: 1) { done.contains($0.completionKey) }
        XCTAssertEqual(next?.week?.number, 1)
        XCTAssertEqual(next?.number, 2)
    }
}

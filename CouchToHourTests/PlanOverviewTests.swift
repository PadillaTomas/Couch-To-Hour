import SwiftData
import XCTest
@testable import CouchToHour

@MainActor
final class PlanOverviewTests: XCTestCase {

    private func plan() throws -> WorkoutPlan {
        let context = try seededContainer().mainContext
        return try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)
    }

    func testCoversEverySessionInOrder() throws {
        let overview = PlanOverview.resolve(plan: try plan(), startingWeek: 1, completions: [])

        XCTAssertEqual(overview.weeks.map(\.number), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(overview.weeks.flatMap(\.days).count, 18)
        for week in overview.weeks {
            XCTAssertEqual(week.days.map(\.day), [1, 2, 3])
        }
        // W1D1 is the seeded 1-min run / 1-min walk ×10.
        let w1d1 = overview.weeks[0].days[0]
        XCTAssertEqual(w1d1.groups, [.init(id: 0, runSeconds: 60, walkSeconds: 60, repeatCount: 10)])
        XCTAssertGreaterThan(w1d1.totalSeconds, 0)
        XCTAssertFalse(w1d1.phases.isEmpty)
    }

    func testDoneAndNextMarkers() throws {
        let done = [CompletionRecord(date: .now, workoutDayKey: "W1D1", durationSeconds: 1200),
                    CompletionRecord(date: .now, workoutDayKey: "W1D2", durationSeconds: 1200)]
        let overview = PlanOverview.resolve(plan: try plan(), startingWeek: 1, completions: done)

        XCTAssertEqual(overview.weeks[0].days[0].state, .done)   // W1D1
        XCTAssertEqual(overview.weeks[0].days[1].state, .done)   // W1D2
        XCTAssertEqual(overview.weeks[0].days[2].state, .next)   // W1D3 — first not done
        XCTAssertEqual(overview.weeks[1].days[0].state, .upcoming)
    }

    func testStartingWeekMarksEarlierWeeksBeforeStart() throws {
        let overview = PlanOverview.resolve(plan: try plan(), startingWeek: 3, completions: [])

        XCTAssertEqual(overview.weeks[0].days[0].state, .beforeStart)   // W1
        XCTAssertEqual(overview.weeks[1].days[2].state, .beforeStart)   // W2
        XCTAssertEqual(overview.weeks[2].days[0].state, .next)          // W3D1 — first eligible
        XCTAssertEqual(overview.weeks[2].days[1].state, .upcoming)
    }

    func testNextSkipsDoneDaysWithinTheStartingWeek() throws {
        let done = [CompletionRecord(date: .now, workoutDayKey: "W3D1", durationSeconds: 1200)]
        let overview = PlanOverview.resolve(plan: try plan(), startingWeek: 3, completions: done)

        XCTAssertEqual(overview.weeks[2].days[0].state, .done)
        XCTAssertEqual(overview.weeks[2].days[1].state, .next)
    }
}

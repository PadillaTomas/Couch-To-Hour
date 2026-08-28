import SwiftData
import XCTest
import UIWorkouts
@testable import CouchToHour

@MainActor
final class PlanSeedTests: XCTestCase {

    private func plan(in context: ModelContext) throws -> WorkoutPlan {
        try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)
    }

    func testSeedsSixWeeksOfThreeDays() throws {
        let context = try TestContainer.seeded().mainContext
        let plan = try plan(in: context)

        XCTAssertEqual(plan.orderedWeeks.map(\.number), [1, 2, 3, 4, 5, 6])
        for week in plan.orderedWeeks {
            XCTAssertEqual(week.orderedDays.map(\.number), [1, 2, 3], "week \(week.number)")
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutDay>()), 18)
    }

    func testSeedIsIdempotent() throws {
        let container = try TestContainer.seeded()
        let context = container.mainContext

        // Snapshot counts, then reseed twice more.
        let intervalCount = try context.fetchCount(FetchDescriptor<Interval>())
        PlanSeed.seed(into: context)
        PlanSeed.seed(into: context)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutPlan>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutWeek>()), 6)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutDay>()), 18)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Interval>()), intervalCount)
    }

    func testIdempotentAcrossAStoreReload() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cth-seed-\(UUID().uuidString).store")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let config = ModelConfiguration(url: url)

        let first = try ModelContainer(for: CouchToHourSchema.schema, configurations: config)
        PlanSeed.seed(into: first.mainContext)
        try first.mainContext.save()

        let relaunch = try ModelContainer(for: CouchToHourSchema.schema, configurations: config)
        PlanSeed.seed(into: relaunch.mainContext)
        try relaunch.mainContext.save()

        XCTAssertEqual(try relaunch.mainContext.fetchCount(FetchDescriptor<WorkoutPlan>()), 1)
        XCTAssertEqual(try relaunch.mainContext.fetchCount(FetchDescriptor<WorkoutDay>()), 18)
    }

    /// Week 1 Day 2 is "(R1 / W1) ×1, then (R2 / W1) ×5" — two groups.
    func testWeek1Day2MatchesSpecNotation() throws {
        let context = try TestContainer.seeded().mainContext
        let plan = try plan(in: context)
        let day = plan.orderedWeeks[0].orderedDays[1]

        let byGroup = Dictionary(grouping: day.orderedIntervals, by: \.group)
        XCTAssertEqual(Set(byGroup.keys), [0, 1])

        let g0 = byGroup[0]!.sorted { $0.order < $1.order }
        XCTAssertEqual(g0.map(\.phase), [.run, .walk])
        XCTAssertEqual(g0.map(\.durationSeconds), [60, 60])
        XCTAssertEqual(g0.first?.repeatCount, 1)

        let g1 = byGroup[1]!.sorted { $0.order < $1.order }
        XCTAssertEqual(g1.map(\.phase), [.run, .walk])
        XCTAssertEqual(g1.map(\.durationSeconds), [120, 60])
        XCTAssertEqual(g1.first?.repeatCount, 5)
    }

    /// Edge case: W6D3 is a single 50-minute continuous run, no walk interval.
    func testWeek6Day3IsOneContinuousRun() throws {
        let context = try TestContainer.seeded().mainContext
        let plan = try plan(in: context)
        let day = plan.orderedWeeks[5].orderedDays[2]

        XCTAssertEqual(day.orderedIntervals.count, 1)
        let only = try XCTUnwrap(day.orderedIntervals.first)
        XCTAssertEqual(only.phase, .run)
        XCTAssertEqual(only.durationSeconds, 3000)

        let session = SessionPlan(day: day)
        XCTAssertEqual(session.phases, [.init(phase: .run, seconds: 3000)])
    }
}

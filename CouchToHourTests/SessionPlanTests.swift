import XCTest
import UIWorkouts
@testable import CouchToHour

final class SessionPlanTests: XCTestCase {

    private func intervals(_ specs: [(Int, Int, WKPhase, Int, Int)]) -> [Interval] {
        specs.map { Interval(order: $0.0, group: $0.1, phase: $0.2, durationSeconds: $0.3, repeatCount: $0.4) }
    }

    /// "(R1 / W1) ×3" expands to R W R W R — the trailing walk is trimmed.
    func testRepeatedChunkExpandsAndTrimsTrailingWalk() {
        let session = SessionPlan(intervals: intervals([
            (0, 0, .run, 60, 3),
            (1, 0, .walk, 60, 3),
        ]))
        XCTAssertEqual(session.phases, [
            .init(phase: .run, seconds: 60),
            .init(phase: .walk, seconds: 60),
            .init(phase: .run, seconds: 60),
            .init(phase: .walk, seconds: 60),
            .init(phase: .run, seconds: 60),
        ])
        XCTAssertEqual(session.runningSeconds, 180)
        XCTAssertEqual(session.totalSeconds, 300)
    }

    /// Edge case W6D1: "R5 / W1, R40 / W1" ends on a walk → session ends after
    /// the last run.
    func testMultiGroupSessionEndsOnLastRun() {
        let session = SessionPlan(intervals: intervals([
            (0, 0, .run, 300, 1),
            (1, 0, .walk, 60, 1),
            (2, 1, .run, 2400, 1),
            (3, 1, .walk, 60, 1),
        ]))
        XCTAssertEqual(session.phases, [
            .init(phase: .run, seconds: 300),
            .init(phase: .walk, seconds: 60),
            .init(phase: .run, seconds: 2400),
        ])
    }

    func testNoWalkChunkIsASingleRun() {
        let session = SessionPlan(intervals: intervals([(0, 0, .run, 3000, 1)]))
        XCTAssertEqual(session.phases, [.init(phase: .run, seconds: 3000)])
    }
}

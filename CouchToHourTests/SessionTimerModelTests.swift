import XCTest
import UIWorkouts
@testable import CouchToHour

@MainActor
final class SessionTimerModelTests: XCTestCase {

    private final class SpyTones: TonePlaying {
        var ticks = 0
        var changes = 0
        func countdownTick() { ticks += 1 }
        func phaseChange() { changes += 1 }
    }

    private func plan(_ specs: [(WKPhase, Int)]) -> SessionPlan {
        SessionPlan(phases: specs.map { .init(phase: $0.0, seconds: $0.1) })
    }

    private func tick(_ model: SessionTimerModel, _ n: Int) {
        for _ in 0..<n { model.tickOneSecond() }
    }

    func testStartsOnTheFirstPhase() {
        let model = SessionTimerModel(plan: plan([(.run, 5), (.walk, 3)]))
        XCTAssertEqual(model.segmentIndex, 0)
        XCTAssertEqual(model.secondsLeftInSegment, 5)
        XCTAssertEqual(model.currentSegment.phase, .run)
        XCTAssertEqual(model.state, .running)
    }

    func testCountsDownAndAdvancesPhasesWithTones() {
        let spy = SpyTones()
        let model = SessionTimerModel(plan: plan([(.run, 5), (.walk, 3), (.run, 5)]), tones: spy)

        tick(model, 5)   // run 5 fully → boundary into walk
        XCTAssertEqual(model.segmentIndex, 1)
        XCTAssertEqual(model.secondsLeftInSegment, 3)
        XCTAssertEqual(spy.ticks, 3)     // 3, 2, 1
        XCTAssertEqual(spy.changes, 1)

        tick(model, 3)   // walk 3 → boundary into run
        XCTAssertEqual(model.segmentIndex, 2)
        XCTAssertEqual(spy.ticks, 5)     // + 2, 1 (a 3s phase never sees "3 left")
        XCTAssertEqual(spy.changes, 2)

        tick(model, 5)   // final run → finished
        XCTAssertEqual(model.state, .finished)
        XCTAssertEqual(spy.ticks, 8)
        XCTAssertEqual(spy.changes, 3)   // last boundary is the end-of-session cue
        XCTAssertEqual(model.elapsedSeconds, 13)
    }

    func testPausedTicksDoNothing() {
        let model = SessionTimerModel(plan: plan([(.run, 10)]))
        model.togglePause()
        XCTAssertEqual(model.state, .paused)
        tick(model, 5)
        XCTAssertEqual(model.secondsLeftInSegment, 10)

        model.togglePause()
        tick(model, 2)
        XCTAssertEqual(model.secondsLeftInSegment, 8)
    }

    func testTicksAfterFinishAreNoOps() {
        let model = SessionTimerModel(plan: plan([(.run, 2)]))
        tick(model, 2)
        XCTAssertEqual(model.state, .finished)
        tick(model, 5)
        XCTAssertEqual(model.state, .finished)
        XCTAssertEqual(model.elapsedSeconds, 2)
    }

    func testEmptyPlanIsImmediatelyFinished() {
        let model = SessionTimerModel(plan: SessionPlan(phases: []))
        XCTAssertEqual(model.state, .finished)
    }

    func testSegmentFraction() {
        let model = SessionTimerModel(plan: plan([(.run, 5)]))
        XCTAssertEqual(model.segmentFraction, 0, accuracy: 0.001)
        tick(model, 2)
        XCTAssertEqual(model.segmentFraction, 0.4, accuracy: 0.001)
    }
}

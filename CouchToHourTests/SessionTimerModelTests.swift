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

    // MARK: Wall-clock sync (returning from the background)

    func testWallClockSyncCatchesUpAcrossPhaseBoundaries() {
        var t = Date(timeIntervalSinceReferenceDate: 0)
        let spy = SpyTones()
        let model = SessionTimerModel(plan: plan([(.run, 5), (.walk, 3), (.run, 5)]),
                                      tones: spy, now: { t })

        t = t.addingTimeInterval(6)   // 6 real seconds pass, app backgrounded
        model.syncToWallClock()

        XCTAssertEqual(model.segmentIndex, 1)          // into the walk
        XCTAssertEqual(model.secondsLeftInSegment, 2)  // 6 - 5 = 1s into a 3s walk
        XCTAssertEqual(spy.changes, 1)                 // the crossed boundary fired
        XCTAssertEqual(spy.ticks, 0)                   // countdown ticks not replayed
    }

    func testWallClockSyncFinishesWhenAwayPastTheEnd() {
        var t = Date(timeIntervalSinceReferenceDate: 0)
        let model = SessionTimerModel(plan: plan([(.run, 5), (.walk, 3)]), now: { t })

        t = t.addingTimeInterval(120)
        model.syncToWallClock()

        XCTAssertEqual(model.state, .finished)
        XCTAssertEqual(model.elapsedSeconds, 8)
    }

    func testWallClockSyncIsANoOpWhilePaused() {
        var t = Date(timeIntervalSinceReferenceDate: 0)
        let model = SessionTimerModel(plan: plan([(.run, 10)]), now: { t })
        model.togglePause()

        t = t.addingTimeInterval(5)
        model.syncToWallClock()

        XCTAssertEqual(model.state, .paused)
        XCTAssertEqual(model.secondsLeftInSegment, 10)
    }

    func testResumeFromPauseStaysAlignedToTheWallClock() {
        var t = Date(timeIntervalSinceReferenceDate: 0)
        let model = SessionTimerModel(plan: plan([(.run, 10)]), now: { t })

        tick(model, 3)                    // 7 left
        model.togglePause()
        t = t.addingTimeInterval(30)      // 30s paused — must not count
        model.togglePause()               // resume
        t = t.addingTimeInterval(4)       // 4 real seconds running
        model.syncToWallClock()

        XCTAssertEqual(model.secondsLeftInSegment, 3)   // 7 - 4
    }

    // MARK: Resume (persisted snapshot)

    private let key = SessionKey(week: 3, day: 2, makeup: false)

    func testSnapshotRoundTripsThroughTheModel() throws {
        let model = SessionTimerModel(plan: plan([(.run, 5), (.walk, 3), (.run, 5)]))
        tick(model, 7)   // 5s run done, 2s into the walk

        let snap = try XCTUnwrap(model.makeSnapshot(for: key))
        XCTAssertEqual(snap.key, key)
        XCTAssertEqual(snap.segmentIndex, 1)
        XCTAssertEqual(snap.secondsLeftInSegment, 1)

        let resumed = SessionTimerModel.resuming(snap)
        XCTAssertEqual(resumed.segmentIndex, 1)
        XCTAssertEqual(resumed.currentSegment.phase, .walk)
        XCTAssertEqual(resumed.secondsLeftInSegment, 1)
        XCTAssertEqual(resumed.state, .running)
    }

    func testFinishedSessionHasNoSnapshot() {
        let model = SessionTimerModel(plan: plan([(.run, 2)]))
        tick(model, 2)
        XCTAssertEqual(model.state, .finished)
        XCTAssertNil(model.makeSnapshot(for: key))
    }

    func testResumeDoesNotCountTimeAwayUntilNextBackgrounding() throws {
        var t = Date(timeIntervalSinceReferenceDate: 0)
        let model = SessionTimerModel(plan: plan([(.run, 10), (.walk, 3)]), now: { t })
        tick(model, 4)                                   // 6 left in the run
        let snap = try XCTUnwrap(model.makeSnapshot(for: key))

        t = t.addingTimeInterval(9999)                   // app was killed, long gone
        let resumed = SessionTimerModel.resuming(snap, now: { t })
        XCTAssertEqual(resumed.secondsLeftInSegment, 6)  // picks up exactly where left off
        XCTAssertEqual(resumed.state, .running)

        t = t.addingTimeInterval(2)
        resumed.syncToWallClock()
        XCTAssertEqual(resumed.secondsLeftInSegment, 4)  // normal catch-up resumes from here
    }

    func testResumingClampsAMalformedSnapshot() {
        let snap = InProgressSession(
            key: key,
            phases: [.init(phaseRaw: "run", seconds: 5)],
            segmentIndex: 99,
            secondsLeftInSegment: 500,
            savedAt: Date(timeIntervalSinceReferenceDate: 0)
        )
        let model = SessionTimerModel.resuming(snap)
        XCTAssertEqual(model.segmentIndex, 0)
        XCTAssertEqual(model.secondsLeftInSegment, 5)
    }

    // MARK: Timer-screen readouts

    func testNextSegmentAndTimeLeft() {
        let model = SessionTimerModel(plan: plan([(.run, 60), (.walk, 90), (.run, 60)]))
        XCTAssertEqual(model.nextSegment?.phase, .walk)
        XCTAssertEqual(model.nextSegment?.seconds, 90)
        XCTAssertEqual(model.totalSecondsLeft, 210)

        tick(model, 60)   // into the walk
        XCTAssertEqual(model.nextSegment?.phase, .run)
        XCTAssertEqual(model.totalSecondsLeft, 150)

        tick(model, 90 + 60)   // finished
        XCTAssertNil(model.nextSegment)
        XCTAssertEqual(model.totalSecondsLeft, 0)
    }

    func testRunIntervalProgress() {
        // run / walk × 3
        let model = SessionTimerModel(plan: plan([
            (.run, 10), (.walk, 5), (.run, 10), (.walk, 5), (.run, 10), (.walk, 5),
        ]))
        XCTAssertEqual(model.runIntervalProgress.total, 3)
        XCTAssertEqual(model.runIntervalProgress.done, 1)   // on run #1

        tick(model, 10)   // into walk after run #1 — still "1 of 3"
        XCTAssertEqual(model.runIntervalProgress.done, 1)

        tick(model, 5)    // into run #2
        XCTAssertEqual(model.runIntervalProgress.done, 2)
    }
}

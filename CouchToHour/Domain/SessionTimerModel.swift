import Foundation
import Observation

/// Drives one workout session: counts down each phase of a ``SessionPlan``,
/// fires the tone cues, and finishes when the last phase ends.
///
/// `tickOneSecond()` is the whole state machine and is called once a second by
/// an internal task — tests call it directly with no real time involved. The
/// countdown is anchored to the wall clock: `syncToWallClock()` reconciles it
/// after the app has been backgrounded (where the per-second task is suspended).
@MainActor
@Observable
final class SessionTimerModel {
    enum State: Equatable { case running, paused, finished }

    let plan: SessionPlan
    private(set) var segmentIndex: Int
    private(set) var secondsLeftInSegment: Int
    private(set) var state: State

    @ObservationIgnored private let tones: TonePlaying
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var ticker: Task<Void, Never>?
    /// Wall-clock instant the current phase started counting down. `nil` while
    /// paused or finished.
    @ObservationIgnored private var segmentStartedAt: Date?

    init(plan: SessionPlan,
         tones: TonePlaying = SilentTonePlayer(),
         now: @escaping () -> Date = { Date() }) {
        self.plan = plan
        self.tones = tones
        self.now = now
        self.segmentIndex = 0
        self.secondsLeftInSegment = plan.phases.first?.seconds ?? 0
        self.state = plan.phases.isEmpty ? .finished : .running
        self.segmentStartedAt = plan.phases.isEmpty ? nil : now()
    }

    /// Rebuild a session from a persisted ``InProgressSession`` — picks up exactly
    /// where the runner left off (pause semantics: time spent away is not
    /// counted). Indices are clamped so a malformed blob can't crash the timer.
    static func resuming(_ snapshot: InProgressSession,
                         tones: TonePlaying = SilentTonePlayer(),
                         now: @escaping () -> Date = { Date() }) -> SessionTimerModel {
        let model = SessionTimerModel(plan: snapshot.sessionPlan, tones: tones, now: now)
        guard !model.plan.phases.isEmpty else { return model }

        model.segmentIndex = min(max(snapshot.segmentIndex, 0), model.plan.phases.count - 1)
        model.secondsLeftInSegment = min(max(snapshot.secondsLeftInSegment, 1),
                                         model.plan.phases[model.segmentIndex].seconds)
        model.segmentStartedAt = now().addingTimeInterval(
            -Double(model.currentSegment.seconds - model.secondsLeftInSegment))
        return model
    }

    /// The phase currently counting down. Clamped so it's safe once finished, and
    /// falls back for an empty plan.
    var currentSegment: SessionPlan.Phase {
        guard !plan.phases.isEmpty else { return .init(phase: .run, seconds: 0) }
        return plan.phases[min(segmentIndex, plan.phases.count - 1)]
    }

    /// 0…1 progress through the current phase, for the dial ring.
    var segmentFraction: Double {
        let total = currentSegment.seconds
        guard total > 0 else { return 1 }
        return Double(total - secondsLeftInSegment) / Double(total)
    }

    /// Seconds elapsed across the whole session.
    var elapsedSeconds: Int {
        let before = plan.phases.prefix(segmentIndex).reduce(0) { $0 + $1.seconds }
        let inCurrent = state == .finished ? 0 : (currentSegment.seconds - secondsLeftInSegment)
        return before + inCurrent
    }

    // MARK: Ticking

    /// One second of session time. Idempotent w.r.t. `paused`/`finished` — a no-op
    /// unless running.
    func tickOneSecond() {
        guard state == .running else { return }

        secondsLeftInSegment -= 1

        if (1...3).contains(secondsLeftInSegment) {
            tones.countdownTick()
        }

        if secondsLeftInSegment <= 0 {
            advanceSegment()
        }
    }

    /// Reconcile the countdown with real elapsed time. Call on returning to the
    /// foreground: the per-second task is suspended while the app is backgrounded,
    /// so the countdown would otherwise lag by the time spent away. Rolls forward
    /// through any phases that ended in the meantime and fires their change cues
    /// (the per-second countdown ticks are not replayed).
    func syncToWallClock() {
        guard state == .running, let started = segmentStartedAt else { return }
        var elapsedInSegment = Int(now().timeIntervalSince(started).rounded(.down))
        guard elapsedInSegment >= 1 else { return }

        while state == .running {
            let left = currentSegment.seconds - elapsedInSegment
            if left > 0 {
                secondsLeftInSegment = left
                segmentStartedAt = now().addingTimeInterval(-Double(elapsedInSegment))
                return
            }
            elapsedInSegment = -left            // spill over into the next phase
            advanceSegment()
        }
    }

    /// Move past the phase that just ended: finish, or start the next one and
    /// fire its cue.
    private func advanceSegment() {
        segmentIndex += 1
        if segmentIndex >= plan.phases.count {
            secondsLeftInSegment = 0
            state = .finished
            segmentStartedAt = nil
            ticker?.cancel()
            tones.sessionFinished()
        } else {
            secondsLeftInSegment = plan.phases[segmentIndex].seconds
            segmentStartedAt = now()
            tones.phaseChange()
        }
    }

    /// A persistable snapshot of where the session stands, or `nil` once it has
    /// finished (nothing to resume).
    func makeSnapshot(for key: SessionKey) -> InProgressSession? {
        guard state != .finished else { return nil }
        return InProgressSession(
            key: key,
            phases: plan.phases.map { .init(phaseRaw: $0.phase.rawValue, seconds: $0.seconds) },
            segmentIndex: segmentIndex,
            secondsLeftInSegment: secondsLeftInSegment,
            savedAt: now()
        )
    }

    // MARK: Control

    func start() {
        guard ticker == nil, state != .finished else { return }
        tones.sessionDidBegin()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                self.tickOneSecond()
                if self.state == .finished { return }
            }
        }
    }

    func togglePause() {
        switch state {
        case .running:
            state = .paused
            segmentStartedAt = nil
        case .paused:
            state = .running
            segmentStartedAt = now().addingTimeInterval(
                -Double(currentSegment.seconds - secondsLeftInSegment))
        case .finished:
            break
        }
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
        tones.sessionDidEnd()
    }
}

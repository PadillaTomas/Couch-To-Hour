import Foundation
import Observation

/// Drives one workout session: counts down each phase of a ``SessionPlan``,
/// fires the tone cues, and finishes when the last phase ends.
///
/// `tickOneSecond()` is the whole state machine and is called once a second by
/// an internal task — tests call it directly with no real time involved.
@MainActor
@Observable
final class SessionTimerModel {
    enum State: Equatable { case running, paused, finished }

    let plan: SessionPlan
    private(set) var segmentIndex: Int
    private(set) var secondsLeftInSegment: Int
    private(set) var state: State

    @ObservationIgnored private let tones: TonePlaying
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(plan: SessionPlan, tones: TonePlaying = SilentTonePlayer()) {
        self.plan = plan
        self.tones = tones
        self.segmentIndex = 0
        self.secondsLeftInSegment = plan.phases.first?.seconds ?? 0
        self.state = plan.phases.isEmpty ? .finished : .running
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
            segmentIndex += 1
            if segmentIndex >= plan.phases.count {
                state = .finished
                ticker?.cancel()
            } else {
                secondsLeftInSegment = plan.phases[segmentIndex].seconds
            }
            tones.phaseChange()   // interval change, or the end-of-session cue
        }
    }

    // MARK: Control

    func start() {
        guard ticker == nil, state != .finished else { return }
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
        case .running: state = .paused
        case .paused: state = .running
        case .finished: break
        }
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
    }
}

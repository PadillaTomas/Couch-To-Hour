import SwiftUI
import UIWorkouts

/// The running-session screen: the ``WKTimerDial`` counting down the current
/// phase over a ``WKAmbientBackground`` tinted to the phase. Calls back when the
/// session finishes or the user ends it.
struct TimerView: View {
    let plan: SessionPlan
    /// Which plan session this is — the key the resume snapshot is stored under.
    let key: SessionKey
    /// Session ran to the end. Passes the elapsed seconds for the record.
    var onFinish: (_ elapsedSeconds: Int) -> Void
    /// User bailed out early — nothing is logged.
    var onExit: () -> Void

    @State private var model: SessionTimerModel
    @State private var showExitConfirm = false
    @Environment(\.scenePhase) private var scenePhase

    init(plan: SessionPlan,
         key: SessionKey,
         resume: InProgressSession? = nil,
         dimsOtherAudio: Bool = true,
         onFinish: @escaping (Int) -> Void,
         onExit: @escaping () -> Void) {
        self.plan = plan
        self.key = key
        self.onFinish = onFinish
        self.onExit = onExit
        let tones = SessionCuePlayer(dimsOtherAudio: dimsOtherAudio)
        let model = (resume?.key == key)
            ? SessionTimerModel.resuming(resume!, tones: tones)
            : SessionTimerModel(plan: plan, tones: tones)
        _model = State(initialValue: model)
    }

    private var dialState: WKTimerDial.State {
        switch model.state {
        case .running: return .running
        case .paused: return .paused
        case .finished: return .complete
        }
    }

    var body: some View {
        ZStack {
            WKColor.bg.ignoresSafeArea()
            WKAmbientBackground(phase: model.currentSegment.phase)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, WKSpace.lg)
                    .padding(.top, WKSpace.sm)

                Spacer(minLength: WKSpace.lg)

                WKTimerDial(
                    fraction: model.segmentFraction,
                    phase: model.currentSegment.phase,
                    caption: model.currentSegment.phase == .run
                        ? Copy.Timer.runCaption
                        : Copy.Timer.walkCaption,
                    seconds: model.secondsLeftInSegment,
                    state: dialState
                )
                .frame(width: 300, height: 300)
                .frame(maxWidth: .infinity)

                Text(model.currentSegment.phase == .run
                     ? Copy.Timer.runGuide : Copy.Timer.walkGuide)
                    .wkFont(.displayS)
                    .foregroundStyle(WKColor.textPrimary)
                    .padding(.top, WKSpace.xxl)

                Spacer(minLength: WKSpace.lg)

                if model.state != .finished {
                    upNext
                        .padding(.horizontal, WKSpace.lg)
                    WKSegmentedTrack(segments: trackSegments)
                        .padding(.horizontal, WKSpace.lg)
                        .padding(.top, WKSpace.sm)
                        .padding(.bottom, WKSpace.lg)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if model.state != .finished {
                WKFooterActions {
                    WKButton(model.state == .paused ? Copy.Timer.resume : Copy.Timer.pause,
                             style: .primary) {
                        model.togglePause()
                    }
                    WKButton(Copy.Timer.endSession, style: .secondary) { showExitConfirm = true }
                }
            }
        }
        .onAppear {
            model.start()
            UIApplication.shared.isIdleTimerDisabled = true
            persistSnapshot()
        }
        .onDisappear {
            model.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: model.state) { _, newState in
            if newState == .finished {
                SessionResumeStore.clear()
                onFinish(model.elapsedSeconds)
            } else {
                persistSnapshot()   // pause / resume
            }
        }
        .onChange(of: model.segmentIndex) { _, _ in persistSnapshot() }
        .onChange(of: scenePhase) { _, phase in
            // The per-second task is suspended while backgrounded — catch the
            // countdown up to real elapsed time on the way back, and keep the
            // resume snapshot current across the transition either way.
            if phase == .active { model.syncToWallClock() }
            persistSnapshot()
        }
        .alert(Copy.Timer.endConfirmTitle, isPresented: $showExitConfirm) {
            Button(Copy.Timer.endConfirmConfirm, role: .destructive) {
                model.stop()
                SessionResumeStore.clear()
                onExit()
            }
            Button(Copy.Timer.endConfirmCancel, role: .cancel) {}
        } message: {
            Text(Copy.Timer.endConfirmBody)
        }
    }

    private var header: some View {
        HStack {
            Text(Copy.Today.dayTitle(week: key.week, day: key.day))
                .wkFont(.body)
                .foregroundStyle(WKColor.textSecondary)
            Spacer()
            let progress = model.runIntervalProgress
            WKPill(Copy.Format.ofCount(progress.done, progress.total),
                   tone: model.currentSegment.phase == .run ? .run : .walk)
        }
    }

    private var upNext: some View {
        HStack {
            if let next = model.nextSegment {
                Text(Copy.Timer.nextUp(phase: next.phase.label.lowercased(),
                                       clock: WKTimeFormat.clock(next.seconds)))
            }
            Spacer()
            Text(Copy.Timer.timeLeft(WKTimeFormat.clock(model.totalSecondsLeft)))
                .monospacedDigit()
        }
        .wkFont(.callout)
        .foregroundStyle(WKColor.textSecondary)
    }

    private var trackSegments: [WKTrackSegment] {
        model.plan.phases.enumerated().map { index, phase in
            let progress: WKTrackSegment.Progress =
                index < model.segmentIndex ? .done
                : (index == model.segmentIndex ? .current : .upcoming)
            return WKTrackSegment(id: index, weight: Double(phase.seconds),
                                  progress: progress, phase: phase.phase)
        }
    }

    /// Write (or clear) the resume snapshot for the current session state.
    private func persistSnapshot() {
        if let snapshot = model.makeSnapshot(for: key) {
            SessionResumeStore.save(snapshot)
        } else {
            SessionResumeStore.clear()
        }
    }
}

#Preview {
    TimerView(
        plan: SessionPlan(phases: [
            .init(phase: .run, seconds: 8),
            .init(phase: .walk, seconds: 5),
            .init(phase: .run, seconds: 8),
        ]),
        key: SessionKey(week: 1, day: 1, makeup: false),
        onFinish: { _ in },
        onExit: {}
    )
}

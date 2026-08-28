import SwiftUI
import UIWorkouts

/// The running-session screen: the ``WKTimerDial`` counting down the current
/// phase on the app's calm background, with a soft phase-coloured halo behind
/// it. Calls back when the session finishes or the user ends it.
struct TimerView: View {
    let plan: SessionPlan
    /// Session ran to the end. Passes the elapsed seconds for the record.
    var onFinish: (_ elapsedSeconds: Int) -> Void
    /// User bailed out early — nothing is logged.
    var onExit: () -> Void

    @State private var model: SessionTimerModel
    @State private var showExitConfirm = false

    init(plan: SessionPlan,
         onFinish: @escaping (Int) -> Void,
         onExit: @escaping () -> Void) {
        self.plan = plan
        self.onFinish = onFinish
        self.onExit = onExit
        _model = State(initialValue: SessionTimerModel(plan: plan, tones: SystemTonePlayer()))
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

            RadialGradient(
                gradient: Gradient(colors: [
                    model.currentSegment.phase.color.opacity(model.state == .paused ? 0.05 : 0.13),
                    .clear,
                ]),
                center: .center, startRadius: 8, endRadius: 340
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: model.segmentIndex)

            WKTimerDial(
                fraction: model.segmentFraction,
                phase: model.currentSegment.phase,
                caption: model.currentSegment.phase == .run
                    ? "Conversation pace — if you can't talk, ease off."
                    : "Walk it out, catch your breath.",
                seconds: model.secondsLeftInSegment,
                state: dialState
            )
            .frame(width: 300, height: 300)
            .padding(WKSpace.lg)
        }
        .safeAreaInset(edge: .bottom) {
            if model.state != .finished {
                WKFooterActions {
                    WKButton(model.state == .paused ? "Resume" : "Pause",
                             style: .softPhase(model.currentSegment.phase)) {
                        model.togglePause()
                    }
                    WKButton("End session", style: .quiet) { showExitConfirm = true }
                }
            }
        }
        .onAppear {
            model.start()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            model.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: model.state) { _, newState in
            if newState == .finished { onFinish(model.elapsedSeconds) }
        }
        .alert("End the session?", isPresented: $showExitConfirm) {
            Button("End", role: .destructive) {
                model.stop()
                onExit()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("It won't be marked done.")
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
        onFinish: { _ in },
        onExit: {}
    )
}

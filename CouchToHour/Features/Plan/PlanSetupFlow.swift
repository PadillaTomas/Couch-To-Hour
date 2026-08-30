import SwiftUI
import UIWorkouts

/// The shared plan-setup flow — **mode → starting point → start date** — run at
/// first launch (`includesPhilosophy: true`, appends the calm screen) and again
/// from Settings when the runner wants to change their setup. It only *collects*
/// a ``PlanSetup``; the caller persists it (`OnboardingCompletion.apply`).
struct PlanSetupFlow: View {
    struct Coord: Equatable { var week: Int; var day: Int }

    enum Context: Equatable {
        /// First launch: no history, pick a starting week.
        case onboarding
        /// Re-run from Settings: seed from `current`, offer "continue where you
        /// left off" pointing at `continueAt` (the next not-done session).
        case reconfigure(current: PlanSetup, continueAt: Coord?)
    }

    let context: Context
    var includesPhilosophy = false
    var onComplete: (PlanSetup) -> Void
    var onCancel: (() -> Void)?
    #if DEBUG
    /// DEBUG-only "skip with demo data" hook (onboarding).
    var onDebugSkip: (() -> Void)?
    #endif

    @State private var mode: TrainingMode?
    @State private var startingWeekIndex = 0     // 0-based
    @State private var startingDayIndex = 0      // 0-based
    @State private var pickSpecificWorkout = false
    @State private var startDate = Date()
    @State private var setStartDate = false      // Free only — 3-Day always sets it
    @State private var stepIndex = 0
    @State private var didSeed = false

    private enum Step { case mode, startingPoint, startDate, philosophy }

    private var steps: [Step] {
        includesPhilosophy ? [.mode, .startingPoint, .startDate, .philosophy]
                           : [.mode, .startingPoint, .startDate]
    }
    private var step: Step { steps[min(stepIndex, steps.count - 1)] }
    private var isLastStep: Bool { stepIndex >= steps.count - 1 }

    private var continueCoord: Coord? {
        if case .reconfigure(_, let c) = context { return c }
        return nil
    }
    private var isReconfigure: Bool {
        if case .reconfigure = context { return true }
        return false
    }

    var body: some View {
        ZStack {
            WKColor.bg.ignoresSafeArea()
            ScrollView {
                stepContent
                    .frame(maxWidth: .infinity, alignment: step == .philosophy ? .center : .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .id(stepIndex)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .safeAreaInset(edge: .bottom) { footer }
        .onAppear(perform: seedOnce)
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case .mode:
            OnboardingModeStep(selection: $mode)
                .padding(WKSpace.lg)
        case .startingPoint:
            if isReconfigure {
                StartingPointStep(continueCoord: continueCoord,
                                  pickSpecific: $pickSpecificWorkout,
                                  weekIndex: $startingWeekIndex,
                                  dayIndex: $startingDayIndex)
                    .padding(WKSpace.lg)
            } else {
                OnboardingStartingWeekStep(selectionIndex: $startingWeekIndex)
                    .padding(WKSpace.lg)
            }
        case .startDate:
            StartDateStep(mode: mode ?? .threeDay, date: $startDate, isSet: $setStartDate)
                .padding(WKSpace.lg)
        case .philosophy:
            OnboardingPhilosophyStep()
                .padding(.horizontal, WKSpace.xl)
                .containerRelativeFrame(.vertical, alignment: .center)
        }
    }

    private var footer: some View {
        WKFooterActions {
            WKButton(isLastStep
                     ? (includesPhilosophy ? Copy.Onboarding.footerStart : Copy.PlanSetup.save)
                     : Copy.Onboarding.footerContinue) {
                if isLastStep { onComplete(buildSetup()) }
                else { withAnimation(.snappy) { stepIndex += 1 } }
            }
            .disabled(step == .mode && mode == nil)

            if stepIndex > 0 {
                WKButton(Copy.Onboarding.footerBack, style: .quiet) {
                    withAnimation(.snappy) { stepIndex -= 1 }
                }
            } else if let onCancel {
                WKButton(Copy.PlanSetup.cancel, style: .quiet, action: onCancel)
            }

            #if DEBUG
            if let onDebugSkip {
                WKButton("Skip with demo data", style: .quiet, action: onDebugSkip)
            }
            #endif
        }
    }

    private func seedOnce() {
        guard !didSeed else { return }
        didSeed = true
        guard case .reconfigure(let current, _) = context else { return }
        mode = current.mode
        startingWeekIndex = max(0, current.startingWeek - 1)
        startingDayIndex = max(0, current.startingDay - 1)
        pickSpecificWorkout = false
    }

    private func buildSetup() -> PlanSetup {
        let m = mode ?? .threeDay
        var week = startingWeekIndex + 1
        var day = startingDayIndex + 1
        if isReconfigure, !pickSpecificWorkout, let c = continueCoord {
            week = c.week
            day = c.day
        }
        let day0 = Calendar.current.startOfDay(for: startDate)
        return PlanSetup(
            mode: m,
            startingWeek: week,
            startingDay: day,
            // 3-Day always has a start date (defaults today); Free's is optional.
            startDate: (m == .threeDay || setStartDate) ? day0 : nil
        )
    }
}

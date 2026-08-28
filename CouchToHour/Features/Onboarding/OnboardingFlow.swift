import SwiftData
import SwiftUI
import UIWorkouts

/// First-run flow: mode → starting week → (3-Day only) start weekday →
/// philosophy. On finish it hands off to ``OnboardingCompletion``; the root
/// view's `onboardingCompleted` query then swaps this out for the app.
struct OnboardingFlow: View {
    @Environment(\.modelContext) private var context

    @State private var mode: TrainingMode?
    /// 0-based — index 0 is Week 1.
    @State private var startingWeekIndex = 0
    /// Monday-first picker index.
    @State private var startWeekdayIndex = 0
    @State private var stepIndex = 0

    private enum Step { case mode, startingWeek, startWeekday, philosophy }

    private var steps: [Step] {
        var steps: [Step] = [.mode, .startingWeek]
        if mode == .threeDay { steps.append(.startWeekday) }
        steps.append(.philosophy)   // the calm screen is always last, right before you start
        return steps
    }

    private var step: Step { steps[min(stepIndex, steps.count - 1)] }
    private var isLastStep: Bool { stepIndex >= steps.count - 1 }

    var body: some View {
        ZStack {
            WKColor.bg.ignoresSafeArea()

            // Every step goes through the same ScrollView + id/transition so
            // they all slide in the same way — philosophy included.
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
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case .mode:
            OnboardingModeStep(selection: $mode)
                .padding(WKSpace.lg)
        case .startingWeek:
            OnboardingStartingWeekStep(selectionIndex: $startingWeekIndex)
                .padding(WKSpace.lg)
        case .startWeekday:
            OnboardingStartWeekdayStep(selectionIndex: $startWeekdayIndex)
                .padding(WKSpace.lg)
        case .philosophy:
            OnboardingPhilosophyStep()
                .padding(.horizontal, WKSpace.xl)
                .containerRelativeFrame(.vertical, alignment: .center)
        }
    }

    private var footer: some View {
        WKFooterActions {
            WKButton(isLastStep ? "Start running" : "Continue") { advance() }
                .disabled(step == .mode && mode == nil)
            if stepIndex > 0 {
                WKButton("Back", style: .quiet) {
                    withAnimation(.snappy) { stepIndex -= 1 }
                }
            }
        }
    }

    private func advance() {
        guard isLastStep else {
            withAnimation(.snappy) { stepIndex += 1 }
            return
        }
        OnboardingCompletion.finish(
            .init(mode: mode ?? .threeDay,
                  startingWeek: startingWeekIndex + 1,
                  startWeekdayIndex: startWeekdayIndex),
            in: context
        )
    }
}

#Preview {
    OnboardingFlow()
        .modelContainer(for: UserSettings.self, inMemory: true)
}

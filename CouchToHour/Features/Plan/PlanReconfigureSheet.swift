import SwiftData
import SwiftUI

/// Settings entry into the shared ``PlanSetupFlow`` — seeds it from the current
/// settings, offers "continue where you left off", and applies without touching
/// the onboarding gate.
struct PlanReconfigureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [UserSettings]
    @Query private var plans: [WorkoutPlan]
    @Query(sort: \CompletionRecord.date) private var completions: [CompletionRecord]

    private var current: PlanSetup {
        let s = settingsRows.first
        return PlanSetup(
            mode: s?.mode ?? .threeDay,
            startingWeek: s?.startingWeek ?? 1,
            startingDay: s?.startingDay ?? 1,
            startDate: s?.startDate
        )
    }

    private var continueCoord: PlanSetupFlow.Coord? {
        guard let plan = plans.first else { return nil }
        return PlanPosition.next(in: plan,
                                 startingWeek: current.startingWeek,
                                 startingDay: current.startingDay,
                                 completions: completions)
            .map { PlanSetupFlow.Coord(week: $0.week, day: $0.day) }
    }

    var body: some View {
        PlanSetupFlow(
            context: .reconfigure(current: current, continueAt: continueCoord),
            onComplete: { setup in
                OnboardingCompletion.apply(setup, markOnboardingComplete: false, in: context)
                dismiss()
            },
            onCancel: { dismiss() }
        )
    }
}

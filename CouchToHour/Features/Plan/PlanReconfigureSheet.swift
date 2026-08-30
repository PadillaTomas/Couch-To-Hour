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

    /// "Continue where you left off" — the runner's position in the *current*
    /// plan instance (via ``PlanState``), so pre-reconfigure history doesn't
    /// drag the suggestion forward.
    private var continueCoord: PlanSetupFlow.Coord? {
        PlanState.from(settings: settingsRows, plans: plans, completions: completions)?
            .currentSession.coordinate
            .map { PlanSetupFlow.Coord(week: $0.week, day: $0.day) }
    }

    var body: some View {
        PlanSetupFlow(
            context: .reconfigure(current: current, continueAt: continueCoord),
            onComplete: { setup in
                OnboardingCompletion.apply(setup, markOnboardingComplete: false, in: context)
                // A plan change starts a fresh instance — any half-finished
                // session from the old setup is no longer valid.
                SessionResumeStore.clear()
                dismiss()
            },
            onCancel: { dismiss() }
        )
    }
}

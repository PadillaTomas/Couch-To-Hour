import SwiftData
import SwiftUI

/// Settings entry into the shared ``PlanSetupFlow`` — seeds it from the current
/// settings and applies without touching the onboarding gate.
struct PlanReconfigureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [UserSettings]

    private var current: PlanSetup {
        let s = settingsRows.first
        return PlanSetup(
            mode: s?.mode ?? .threeDay,
            startingWeek: s?.startingWeek ?? 1,
            startingDay: s?.startingDay ?? 1,
            startDate: s?.startDate
        )
    }

    var body: some View {
        PlanSetupFlow(
            context: .reconfigure(current: current),
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

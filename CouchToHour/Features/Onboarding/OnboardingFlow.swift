import SwiftData
import SwiftUI

/// First-run: the shared ``PlanSetupFlow`` with the philosophy screen appended.
/// On finish it writes via ``OnboardingCompletion/apply(_:now:markOnboardingComplete:in:calendar:)``;
/// the root view's `onboardingCompleted` query then swaps this out for the app.
struct OnboardingFlow: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        var flow = PlanSetupFlow(
            context: .onboarding,
            includesPhilosophy: true,
            onComplete: { setup in OnboardingCompletion.apply(setup, in: context) }
        )
        #if DEBUG
        flow.onDebugSkip = { DemoData.loadThreeDay(into: context) }
        #endif
        return flow
    }
}

#Preview {
    OnboardingFlow()
        .modelContainer(for: UserSettings.self, inMemory: true)
}

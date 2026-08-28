import Foundation
import SwiftData

/// Wipes the user's progress and sends them back through onboarding. The fixed
/// 6-week plan itself is left in place — re-seeding is idempotent and there is
/// nothing user-owned about it.
enum AppReset {

    /// Deletes completion history, clears every scheduled date, and resets
    /// `UserSettings` to its first-run state (keeping the theme). The root
    /// view's `onboardingCompleted` query then swaps the app for onboarding.
    static func performFullReset(in context: ModelContext) {
        for record in (try? context.fetch(FetchDescriptor<CompletionRecord>())) ?? [] {
            context.delete(record)
        }

        if let plan = try? context.fetch(FetchDescriptor<WorkoutPlan>()).first {
            ScheduleGenerator.clearSchedule(for: plan)
        }

        UserSettings.current(in: context).resetToFirstRun()

        try? context.save()
    }
}

import Foundation
import SwiftData

/// Wipes the user's progress and sends them back through onboarding. The fixed
/// 6-week plan itself is left in place — re-seeding is idempotent and there is
/// nothing user-owned about it.
enum AppReset {

    /// Deletes completion history and resets `UserSettings` to its first-run
    /// state (keeping the theme). The schedule is derived from those settings,
    /// so there's nothing else to clear. The root view's `onboardingCompleted`
    /// query then swaps the app for onboarding.
    static func performFullReset(in context: ModelContext) {
        for record in (try? context.fetch(FetchDescriptor<CompletionRecord>())) ?? [] {
            context.delete(record)
        }

        UserSettings.current(in: context).resetToFirstRun()

        context.saveChanges("reset")
    }
}

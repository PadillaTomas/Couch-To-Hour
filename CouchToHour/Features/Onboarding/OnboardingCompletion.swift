import Foundation
import SwiftData

/// The side-effecting write of a ``PlanSetup``: pushes the four plan inputs to
/// `UserSettings` and — at first launch only — flips the first-run gate. The
/// schedule itself is *not* written anywhere; it's derived from these inputs on
/// demand (see ``PlanState``). Split out from the view so it can be unit-tested.
enum OnboardingCompletion {

    /// Apply a setup.
    /// - Parameters:
    ///   - now: fallback start date when the setup doesn't carry one.
    ///   - markOnboardingComplete: `true` from first-run onboarding, `false` when
    ///     re-running setup from Settings.
    static func apply(_ setup: PlanSetup,
                      now: Date = .now,
                      markOnboardingComplete: Bool = true,
                      in context: ModelContext,
                      calendar: Calendar = .current) {
        let settings = UserSettings.current(in: context)
        settings.mode = setup.mode
        settings.startingWeek = setup.startingWeek
        settings.startingDay = setup.startingDay
        // Every (re)configuration starts a fresh plan instance: from here on,
        // progression follows the new plan and the new schedule. Sessions logged
        // before this instant stay on the calendar but no longer pre-complete
        // anything (see `PlanState.planCompletions`).
        settings.planEpoch = now

        switch setup.mode {
        case .threeDay:
            let startDate = calendar.startOfDay(for: setup.startDate ?? now)
            settings.startDate = startDate
            settings.startWeekday = calendar.component(.weekday, from: startDate)   // for display
        case .free:
            // A reconfigure from Settings takes effect *today* unless the runner
            // picked an explicit future date — that anchor is what lets Today
            // show the chosen starting session even if it was done on an earlier
            // pass (see `TodaySession.resolve`). First-run onboarding keeps the
            // date optional (nil = "no start date set").
            if let picked = setup.startDate {
                settings.startDate = calendar.startOfDay(for: picked)
            } else if !markOnboardingComplete {
                settings.startDate = calendar.startOfDay(for: now)
            } else {
                settings.startDate = nil
            }
        }

        if markOnboardingComplete { settings.onboardingCompleted = true }
        context.saveChanges("plan setup")
    }
}

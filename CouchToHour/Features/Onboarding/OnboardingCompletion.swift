import Foundation
import SwiftData

/// The side-effecting write of a ``PlanSetup``: pushes it to `UserSettings`,
/// (re)builds or clears the schedule, and — at first launch only — flips the
/// first-run gate. Split out from the view so it can be unit-tested.
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

        let plan = try? context.fetch(FetchDescriptor<WorkoutPlan>()).first

        switch setup.mode {
        case .threeDay:
            let startDate = calendar.startOfDay(for: setup.startDate ?? now)
            settings.startDate = startDate
            settings.startWeekday = calendar.component(.weekday, from: startDate)   // for display
            if let plan {
                ScheduleGenerator.apply(to: plan,
                                        startingWeek: setup.startingWeek,
                                        startingDay: setup.startingDay,
                                        startDate: startDate,
                                        calendar: calendar)
            }
        case .free:
            settings.startDate = setup.startDate.map { calendar.startOfDay(for: $0) }
            if let plan { ScheduleGenerator.clearSchedule(for: plan) }
        }

        if markOnboardingComplete { settings.onboardingCompleted = true }
        try? context.save()
    }
}

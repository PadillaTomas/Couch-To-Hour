import Foundation

/// A complete plan-setup choice — the output of the shared setup flow, whether
/// it ran at first-launch (onboarding) or later from Settings. Applied by
/// ``OnboardingCompletion/apply(_:now:markOnboardingComplete:in:calendar:)``.
struct PlanSetup: Equatable {
    var mode: TrainingMode
    /// 1-based plan coordinate to (re)start from.
    var startingWeek: Int
    var startingDay: Int
    /// The day `(startingWeek, startingDay)` happens.
    /// - 3-Day: the schedule is generated from here. `nil` → today.
    /// - Free: an optional first-run date for the calendar. `nil` → not set.
    var startDate: Date?

    init(mode: TrainingMode,
         startingWeek: Int,
         startingDay: Int = 1,
         startDate: Date? = nil) {
        self.mode = mode
        self.startingWeek = startingWeek
        self.startingDay = startingDay
        self.startDate = startDate
    }
}

/// Where the runner currently stands in the plan — the next session they'd do.
/// Used to offer "Continue where you left off" when re-running setup.
enum PlanPosition {
    /// First not-done session at or after `(startingWeek, startingDay)`, in
    /// week/day order. `nil` once the whole plan is complete.
    static func next(in plan: WorkoutPlan,
                     startingWeek: Int,
                     startingDay: Int,
                     completions: [CompletionRecord]) -> (week: Int, day: Int)? {
        for week in plan.orderedWeeks where week.number >= startingWeek {
            for day in week.orderedDays
            where !(week.number == startingWeek && day.number < startingDay) {
                if !DoneDetection.isComplete(day, among: completions) {
                    return (week.number, day.number)
                }
            }
        }
        return nil
    }
}

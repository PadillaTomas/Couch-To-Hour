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

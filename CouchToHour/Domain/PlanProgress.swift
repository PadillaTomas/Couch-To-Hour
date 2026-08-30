import Foundation

/// The one naive "where has the runner got to" walk: the first not-completed
/// `(week, day)` at or after a starting coordinate, in `D1 → D2 → D3`, week
/// order. `nil` once everything from there on is done.
///
/// This is the *raw* position — it knows nothing about dates, 3-Day scheduling,
/// missed days, or the parked-restart rule. `TodaySession.resolve` layers those
/// on; `PlanOverview` and "continue where you left off" use it directly.
enum PlanProgress {
    static func nextIncomplete(in plan: WorkoutPlan,
                               startingWeek: Int,
                               startingDay: Int = 1,
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

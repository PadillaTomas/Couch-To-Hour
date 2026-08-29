import Foundation

/// Free mode progression: no dates, no scheduling. The next session is simply
/// the first day the user has not completed yet, in `D1 → D2 → D3`, week order.
enum FreeProgression {

    /// - Parameters:
    ///   - plan: the seeded plan.
    ///   - startingWeek: weeks before this are skipped (experienced-runner
    ///     start-ahead choice).
    ///   - startingDay: days before this *within* `startingWeek` are skipped too.
    ///   - isComplete: whether a given day already has a completion record.
    /// - Returns: the next day to do, or `nil` when every day from
    ///   `(startingWeek, startingDay)` on is done.
    static func nextDay(in plan: WorkoutPlan,
                        startingWeek: Int,
                        startingDay: Int = 1,
                        isComplete: (WorkoutDay) -> Bool) -> WorkoutDay? {
        for week in plan.orderedWeeks where week.number >= startingWeek {
            for day in week.orderedDays
            where !(week.number == startingWeek && day.number < startingDay) && !isComplete(day) {
                return day
            }
        }
        return nil
    }
}

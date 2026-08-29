import Foundation

/// The whole 6-week plan flattened for a read-only browse screen — every week,
/// every day, with its interval shape and (optionally) where the user stands.
/// Pure; the view maps it onto cards.
struct PlanOverview: Equatable {

    enum DayState: Equatable {
        /// Completed (has a `CompletionRecord`).
        case done
        /// The first not-done day at or after the chosen starting week.
        case next
        /// Still ahead.
        case upcoming
        /// In a week the user chose to skip past at onboarding.
        case beforeStart
    }

    struct Day: Equatable, Identifiable {
        let week: Int
        let day: Int
        let totalSeconds: Int
        /// The flattened phase list, for the expanded track.
        let phases: [SessionPlan.Phase]
        /// The `(R / W) ×N` blocks, for the expanded breakdown.
        let groups: [SessionPlan.Group]
        let state: DayState
        var id: String { "W\(week)D\(day)" }
    }

    struct Week: Equatable, Identifiable {
        let number: Int
        let days: [Day]
        var id: Int { number }
    }

    let weeks: [Week]

    /// - Parameters:
    ///   - startingWeek: 1…6; weeks before it are marked `.beforeStart`.
    ///   - completions: history, for the `.done` / `.next` markers. Pass `[]`
    ///     (and ignore progress in the view) for the onboarding browse.
    static func resolve(plan: WorkoutPlan,
                        startingWeek: Int,
                        completions: [CompletionRecord]) -> PlanOverview {
        let isDone: (WorkoutDay) -> Bool = { DoneDetection.isComplete($0, among: completions) }

        // "Next" = first not-done day, in week/day order, at or after startingWeek.
        var nextID: String?
        for week in plan.orderedWeeks where week.number >= startingWeek {
            if let day = week.orderedDays.first(where: { !isDone($0) }) {
                nextID = "W\(week.number)D\(day.number)"
                break
            }
        }

        let weeks = plan.orderedWeeks.map { week in
            Week(number: week.number, days: week.orderedDays.map { day in
                let id = "W\(week.number)D\(day.number)"
                let state: DayState
                if isDone(day) { state = .done }
                else if id == nextID { state = .next }
                else if week.number < startingWeek { state = .beforeStart }
                else { state = .upcoming }

                let sessionPlan = SessionPlan(day: day)
                return Day(week: week.number,
                           day: day.number,
                           totalSeconds: sessionPlan.totalSeconds,
                           phases: sessionPlan.phases,
                           groups: SessionPlan.groups(of: day),
                           state: state)
            })
        }
        return PlanOverview(weeks: weeks)
    }
}

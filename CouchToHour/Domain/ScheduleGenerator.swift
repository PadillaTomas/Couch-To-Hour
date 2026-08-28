import Foundation

/// 3-Day mode schedule generation: a start weekday plus an anchor date become
/// concrete dated sessions, one rest day between each, covering every remaining
/// week of the plan. Pure — the persistence side lives in ``apply(to:...)``.
enum ScheduleGenerator {

    struct Slot: Equatable {
        var week: Int
        var day: Int
        var date: Date
    }

    /// - Parameters:
    ///   - startingWeek: first plan week to schedule (1…6).
    ///   - startWeekday: `Calendar` weekday the training week starts on,
    ///     1 (Sunday)…7 (Saturday). Each week's D1 lands on this weekday.
    ///   - anchor: reference "now". The first D1 is the first `startWeekday`
    ///     on or after the start of `anchor`'s day (so an anchor already on the
    ///     start weekday schedules D1 for that same day).
    ///
    /// Within a week: D1 → D2 → D3 are two days apart (one rest day between).
    /// Between weeks: each D1 is exactly 7 days after the previous week's D1.
    static func schedule(startingWeek: Int,
                         startWeekday: Int,
                         anchor: Date,
                         calendar: Calendar = .current) -> [Slot] {
        guard (1...6).contains(startingWeek) else { return [] }

        let startOfAnchor = calendar.startOfDay(for: anchor)
        let anchorWeekday = calendar.component(.weekday, from: startOfAnchor)
        let leadDays = ((startWeekday - anchorWeekday) % 7 + 7) % 7
        guard let firstD1 = calendar.date(byAdding: .day, value: leadDays, to: startOfAnchor) else {
            return []
        }

        var slots: [Slot] = []
        for week in startingWeek...6 {
            let weekOffset = (week - startingWeek) * 7
            for day in 1...3 {
                let offset = weekOffset + (day - 1) * 2
                if let date = calendar.date(byAdding: .day, value: offset, to: firstD1) {
                    slots.append(Slot(week: week, day: day, date: date))
                }
            }
        }
        return slots
    }

    /// Writes generated dates onto the plan's `WorkoutDay` rows. Days outside
    /// `startingWeek…6` are cleared.
    static func apply(to plan: WorkoutPlan,
                      startingWeek: Int,
                      startWeekday: Int,
                      anchor: Date,
                      calendar: Calendar = .current) {
        let dates = Dictionary(
            uniqueKeysWithValues: schedule(startingWeek: startingWeek,
                                           startWeekday: startWeekday,
                                           anchor: anchor,
                                           calendar: calendar)
                .map { (WorkoutDay.completionKey(week: $0.week, day: $0.day), $0.date) }
        )
        for week in plan.orderedWeeks {
            for day in week.orderedDays {
                day.scheduledDate = dates[WorkoutDay.completionKey(week: week.number, day: day.number)]
            }
        }
    }

    /// Free mode: no dated schedule.
    static func clearSchedule(for plan: WorkoutPlan) {
        for week in plan.weeks {
            for day in week.days { day.scheduledDate = nil }
        }
    }
}

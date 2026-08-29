import Foundation

/// 3-Day mode schedule generation: a **start date** becomes concrete dated
/// sessions, one rest day between each, covering every remaining week of the
/// plan. Pure — the persistence side lives in ``apply(to:...)``.
enum ScheduleGenerator {

    struct Slot: Equatable {
        var week: Int
        var day: Int
        var date: Date
    }

    /// - Parameters:
    ///   - startingWeek: first plan week to schedule (1…6).
    ///   - startingDay: first plan day within `startingWeek` (1…3). Earlier days
    ///     of that week are omitted.
    ///   - startDate: the day `(startingWeek, startingDay)` happens. Every other
    ///     session is counted forward from here.
    ///
    /// Within a week: D1 → D2 → D3 are two days apart (one rest day between).
    /// Between weeks: each week's D1 is exactly 7 days after the previous week's.
    static func schedule(startingWeek: Int,
                         startingDay: Int = 1,
                         startDate: Date,
                         calendar: Calendar = .current) -> [Slot] {
        guard (1...6).contains(startingWeek), (1...3).contains(startingDay) else { return [] }

        let firstSession = calendar.startOfDay(for: startDate)
        // Where D1 of `startingWeek` sits (maybe before `firstSession`) so that
        // (startingWeek, startingDay) lands exactly on it.
        guard let weekD1 = calendar.date(byAdding: .day,
                                         value: -(startingDay - 1) * 2, to: firstSession)
        else { return [] }

        var slots: [Slot] = []
        for week in startingWeek...6 {
            for day in 1...3 where !(week == startingWeek && day < startingDay) {
                let offset = (week - startingWeek) * 7 + (day - 1) * 2
                if let date = calendar.date(byAdding: .day, value: offset, to: weekD1) {
                    slots.append(Slot(week: week, day: day, date: date))
                }
            }
        }
        return slots
    }

    /// Writes generated dates onto the plan's `WorkoutDay` rows. Days outside
    /// the `(startingWeek, startingDay)…(6, 3)` range are cleared.
    static func apply(to plan: WorkoutPlan,
                      startingWeek: Int,
                      startingDay: Int = 1,
                      startDate: Date,
                      calendar: Calendar = .current) {
        let dates = Dictionary(
            uniqueKeysWithValues: schedule(startingWeek: startingWeek,
                                           startingDay: startingDay,
                                           startDate: startDate,
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

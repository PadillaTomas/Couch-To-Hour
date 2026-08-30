import Foundation

/// 3-Day mode schedule generation: a **start date** becomes concrete dated
/// sessions, one rest day between each, covering every remaining week of the
/// plan. Pure and stateless — the schedule is *never* persisted, it's derived
/// on demand from the four `UserSettings` inputs (see ``PlanState``).
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
}

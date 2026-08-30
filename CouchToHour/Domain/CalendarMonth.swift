import Foundation
import UIWorkouts

/// One month of the Calendar tab, resolved from the schedule + completion
/// history. Pure — the view maps `days` onto `WKDay`s.
struct CalendarMonth: Equatable {
    struct Day: Equatable, Identifiable {
        var id: Int          // day of month
        var number: Int
        var state: WKDay.State
    }

    var title: String              // "September 2026"
    var weekdaySymbols: [String]    // Monday-first, matches onboarding
    var leadingBlanks: Int
    var days: [Day]

    static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]
    static let weekdaySymbolsMondayFirst = ["M", "T", "W", "T", "F", "S", "S"]

    /// - Parameters:
    ///   - monthContaining: any date in the month to render.
    ///   - schedule: the resolved upcoming sessions (`[]` when there's no dated
    ///     schedule — Free mode with no start date ahead). 3-Day / Free is not a
    ///     distinction here; both come in as slots via ``PlanState``.
    static func resolve(monthContaining date: Date,
                        schedule: [ScheduleGenerator.Slot],
                        completions: [CompletionRecord],
                        today: Date,
                        calendar: Calendar = .current) -> CalendarMonth {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let dayCount = calendar.range(of: .day, in: .month, for: monthStart)!.count

        // Monday-first column for the 1st (Calendar weekday: 1 Sun … 7 Sat).
        let leadingBlanks = (calendar.component(.weekday, from: monthStart) - 2 + 7) % 7

        let scheduledDates = schedule.map(\.date)
        let startOfToday = calendar.startOfDay(for: today)

        let days: [Day] = (1...dayCount).map { number in
            let dayDate = calendar.date(byAdding: .day, value: number - 1, to: monthStart)!
            let isDone = completions.contains { calendar.isDate($0.date, inSameDayAs: dayDate) }
            let isToday = calendar.isDate(dayDate, inSameDayAs: startOfToday)
            let isFutureScheduled = dayDate > startOfToday
                && scheduledDates.contains { calendar.isDate($0, inSameDayAs: dayDate) }

            let state: WKDay.State
            if isDone { state = .done }
            else if isToday { state = .today }
            else if isFutureScheduled { state = .scheduled }
            else { state = .default }

            return Day(id: number, number: number, state: state)
        }

        let month = calendar.component(.month, from: monthStart)
        let year = calendar.component(.year, from: monthStart)

        return CalendarMonth(
            title: "\(monthNames[month - 1]) \(year)",
            weekdaySymbols: weekdaySymbolsMondayFirst,
            leadingBlanks: leadingBlanks,
            days: days
        )
    }
}

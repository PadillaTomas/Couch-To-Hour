import Foundation

/// Missed-day handling for 3-Day mode — Option C from the spec: *ask, don't
/// auto-slide or silently enforce the grid*. Given today and the completion
/// history, produce the decision the next-app-open prompt needs. Logic only;
/// the prompt UI is CTH-7.
enum MissedDayResolver {

    enum Resolution: Equatable {
        /// A session is scheduled for today and nothing earlier is outstanding —
        /// just do it.
        case onTrack(week: Int, day: Int)
        /// Nothing scheduled today and nothing outstanding — a rest day.
        case rest
        /// An earlier scheduled session was missed. Prompt: do the missed one,
        /// or go to `current` (today's session, if there is one — `nil` if today
        /// is itself a rest day).
        case missed(missedWeek: Int, missedDay: Int, currentWeek: Int?, currentDay: Int?)
        /// Every scheduled session is complete.
        case planComplete
    }

    /// - Parameters:
    ///   - today: the current date.
    ///   - slots: the generated schedule (see ``ScheduleGenerator/schedule(startingWeek:startWeekday:anchor:calendar:)``).
    ///   - isComplete: whether the `(week, day)` session has a completion record.
    static func resolve(today: Date,
                        slots: [ScheduleGenerator.Slot],
                        isComplete: (_ week: Int, _ day: Int) -> Bool,
                        calendar: Calendar = .current) -> Resolution {
        guard !slots.isEmpty else { return .rest }

        let startOfToday = calendar.startOfDay(for: today)

        if slots.allSatisfy({ isComplete($0.week, $0.day) }) {
            return .planComplete
        }

        let todaySlot = slots.first { calendar.isDate($0.date, inSameDayAs: startOfToday) }
        let currentToday = todaySlot.flatMap { isComplete($0.week, $0.day) ? nil : $0 }

        let earliestOutstanding = slots
            .filter { calendar.startOfDay(for: $0.date) <= startOfToday }
            .filter { !isComplete($0.week, $0.day) }
            .min { $0.date < $1.date }

        guard let missed = earliestOutstanding else {
            // Caught up on everything due so far.
            if let currentToday { return .onTrack(week: currentToday.week, day: currentToday.day) }
            return .rest
        }

        // The earliest outstanding session being *today* is not a miss.
        if calendar.isDate(missed.date, inSameDayAs: startOfToday) {
            return .onTrack(week: missed.week, day: missed.day)
        }

        return .missed(missedWeek: missed.week,
                       missedDay: missed.day,
                       currentWeek: currentToday?.week,
                       currentDay: currentToday?.day)
    }
}

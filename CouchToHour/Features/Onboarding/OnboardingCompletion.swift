import Foundation
import SwiftData

/// The one side-effecting step of onboarding, split out from the view so it can
/// be unit-tested: writes the user's choices to `UserSettings`, populates (or
/// clears) the schedule, and flips the first-run gate.
enum OnboardingCompletion {

    /// Weekday-picker symbols, Monday-first. The picker's `selection` is a
    /// 0-based index into this array.
    static let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]

    /// Maps a Monday-first picker index (0…6) to a `Calendar` weekday
    /// (1 Sunday…7 Saturday), matching `UserSettings.startWeekday`.
    static func calendarWeekday(fromMondayFirstIndex index: Int) -> Int {
        (index + 1) % 7 + 1
    }

    struct Choices {
        var mode: TrainingMode
        var startingWeek: Int
        /// Monday-first picker index; ignored in Free mode.
        var startWeekdayIndex: Int
    }

    /// - Parameters:
    ///   - now: anchor for schedule generation (the 3-Day `startDate`).
    ///   - calendar: injected for tests.
    static func finish(_ choices: Choices,
                       now: Date = .now,
                       in context: ModelContext,
                       calendar: Calendar = .current) {
        let settings = UserSettings.current(in: context)
        settings.mode = choices.mode
        settings.startingWeek = choices.startingWeek

        let plan = try? context.fetch(FetchDescriptor<WorkoutPlan>()).first

        switch choices.mode {
        case .threeDay:
            let weekday = calendarWeekday(fromMondayFirstIndex: choices.startWeekdayIndex)
            settings.startWeekday = weekday
            settings.startDate = now
            if let plan {
                ScheduleGenerator.apply(to: plan,
                                        startingWeek: choices.startingWeek,
                                        startWeekday: weekday,
                                        anchor: now,
                                        calendar: calendar)
            }
        case .free:
            settings.startDate = nil
            if let plan { ScheduleGenerator.clearSchedule(for: plan) }
        }

        settings.onboardingCompleted = true
        try? context.save()
    }
}

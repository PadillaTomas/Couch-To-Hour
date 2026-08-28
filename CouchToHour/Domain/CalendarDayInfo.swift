import Foundation

/// What to show at the bottom of the Calendar tab for the selected day.
enum CalendarDayInfo: Equatable {
    /// A completed session.
    case done(week: Int, day: Int, groups: [SessionPlan.Group], durationSeconds: Int, feltRating: Int?)
    /// A scheduled session (3-Day) — future, or today.
    case scheduled(week: Int, day: Int, groups: [SessionPlan.Group], isToday: Bool)
    /// Nothing on this day.
    case rest

    static func resolve(date: Date,
                        mode: TrainingMode,
                        plan: WorkoutPlan?,
                        completions: [CompletionRecord],
                        today: Date,
                        calendar: Calendar = .current) -> CalendarDayInfo {
        if let record = completions.first(where: { calendar.isDate($0.date, inSameDayAs: date) }),
           let coord = record.workoutCoordinate,
           let workoutDay = plan?.day(week: coord.week, day: coord.day) {
            return .done(week: coord.week, day: coord.day,
                         groups: SessionPlan.groups(of: workoutDay),
                         durationSeconds: record.durationSeconds,
                         feltRating: record.feltRating)
        }

        if mode == .threeDay,
           let workoutDay = (plan?.orderedWeeks.flatMap(\.orderedDays) ?? []).first(where: {
               $0.scheduledDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
           }),
           let week = workoutDay.week?.number {
            return .scheduled(week: week, day: workoutDay.number,
                              groups: SessionPlan.groups(of: workoutDay),
                              isToday: calendar.isDate(date, inSameDayAs: today))
        }

        return .rest
    }
}

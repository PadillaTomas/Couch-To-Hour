import Foundation

/// What to show at the bottom of the Calendar tab for the selected day — every
/// session logged that day (there can be more than one), plus any scheduled one.
enum CalendarDayInfo: Equatable {
    struct Item: Equatable {
        enum Status: Equatable {
            case done(durationSeconds: Int, feltRating: Int?)
            case scheduled(isToday: Bool)
        }
        var week: Int
        var day: Int
        var groups: [SessionPlan.Group]
        var status: Status

        var isDone: Bool { if case .done = status { return true } else { return false } }
    }

    case sessions([Item])
    case rest

    static func resolve(date: Date,
                        mode: TrainingMode,
                        plan: WorkoutPlan?,
                        completions: [CompletionRecord],
                        today: Date,
                        freeFirstSession: (date: Date, week: Int, day: Int)? = nil,
                        calendar: Calendar = .current) -> CalendarDayInfo {
        var items: [Item] = []

        // Every session logged on this day, in the order it was logged.
        for record in completions
        where calendar.isDate(record.date, inSameDayAs: date) {
            guard let coord = record.workoutCoordinate,
                  let workoutDay = plan?.day(week: coord.week, day: coord.day) else { continue }
            items.append(Item(week: coord.week, day: coord.day,
                              groups: SessionPlan.groups(of: workoutDay),
                              status: .done(durationSeconds: record.durationSeconds,
                                            feltRating: record.feltRating)))
        }

        // A session scheduled for this day, unless a completion already covers it.
        let scheduled: (week: Int, day: Int)? = {
            if mode == .free, let f = freeFirstSession,
               calendar.isDate(f.date, inSameDayAs: date) {
                return (f.week, f.day)
            }
            if mode == .threeDay,
               let d = (plan?.orderedWeeks.flatMap(\.orderedDays) ?? []).first(where: {
                   $0.scheduledDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
               }), let week = d.week?.number {
                return (week, d.number)
            }
            return nil
        }()
        if let s = scheduled,
           let workoutDay = plan?.day(week: s.week, day: s.day),
           !items.contains(where: { $0.week == s.week && $0.day == s.day }) {
            items.append(Item(week: s.week, day: s.day,
                              groups: SessionPlan.groups(of: workoutDay),
                              status: .scheduled(isToday: calendar.isDate(date, inSameDayAs: today))))
        }

        return items.isEmpty ? .rest : .sessions(items)
    }
}

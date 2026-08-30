import Foundation

/// What the Today tab should show right now, resolved from the mode, the plan,
/// the schedule (3-Day) and the completion history. Pure — the view maps this
/// onto `WorkoutDay`s and screens.
enum TodaySession: Equatable {
    /// A session to do now. `makeup` marks it as an earlier missed session that
    /// the user chose (or was left with) rather than today's scheduled one.
    case session(week: Int, day: Int, makeup: Bool)

    /// 3-Day, Option C: an earlier session was missed *and* a different one is
    /// due today. The prompt lets the user pick.
    case missedChoice(missedWeek: Int, missedDay: Int, todayWeek: Int, todayDay: Int)

    /// 3-Day: nothing due today and nothing outstanding.
    case rest

    /// The runner set a start date that hasn't arrived yet — nothing to do until then.
    case notStartedYet(Date)

    /// Every session is done.
    case planComplete

    /// The `(week, day)` this resolves to for screens that need a plain
    /// coordinate (Calendar's upcoming marker). `nil` when there's nothing to
    /// point at (rest / not-started / plan complete). For an Option-C choice it
    /// points at today's session.
    var coordinate: (week: Int, day: Int)? {
        switch self {
        case .session(let w, let d, _): return (w, d)
        case .missedChoice(_, _, let tw, let td): return (tw, td)
        case .rest, .notStartedYet, .planComplete: return nil
        }
    }

    static func resolve(mode: TrainingMode,
                        plan: WorkoutPlan,
                        startingWeek: Int,
                        startingDay: Int = 1,
                        startDate: Date?,
                        completions: [CompletionRecord],
                        today: Date,
                        calendar: Calendar = .current) -> TodaySession {
        let isDone: (Int, Int) -> Bool = { week, day in
            DoneDetection.isComplete(week: week, day: day, among: completions)
        }

        // A future start date the runner picked, before they've done anything.
        if completions.isEmpty, let startDate,
           calendar.startOfDay(for: startDate) > calendar.startOfDay(for: today) {
            return .notStartedYet(calendar.startOfDay(for: startDate))
        }

        switch mode {
        case .free:
            // The runner (re)set their starting point on `startDate`. On that day
            // Today shows exactly `(startingWeek, startingDay)` — even if it was
            // completed on an earlier pass — until they log it again today. Older
            // completion records are never altered; the next day normal
            // progression resumes on its own.
            if let startDate, calendar.isDate(startDate, inSameDayAs: today),
               !parkedLoggedToday(startingWeek, startingDay, completions, today, calendar) {
                return .session(week: startingWeek, day: startingDay, makeup: false)
            }

            guard let next = PlanProgress.nextIncomplete(in: plan, startingWeek: startingWeek,
                                                        startingDay: startingDay,
                                                        completions: completions)
            else { return .planComplete }
            return .session(week: next.week, day: next.day, makeup: false)

        case .threeDay:
            let slots = ScheduleGenerator.schedule(startingWeek: startingWeek,
                                                   startingDay: startingDay,
                                                   startDate: startDate ?? today,
                                                   calendar: calendar)

            // The session the runner parked the plan at shows on its scheduled
            // day even if it was completed before — they explicitly chose to
            // (re)start here. Once they log it *today*, it drops back to the
            // normal "done for today" flow.
            if !parkedLoggedToday(startingWeek, startingDay, completions, today, calendar),
               slots.contains(where: {
                $0.week == startingWeek && $0.day == startingDay
                    && calendar.isDate($0.date, inSameDayAs: today)
            }) {
                return .session(week: startingWeek, day: startingDay, makeup: false)
            }

            switch MissedDayResolver.resolve(today: today, slots: slots,
                                             isComplete: isDone, calendar: calendar) {
            case .onTrack(let week, let day):
                return .session(week: week, day: day, makeup: false)
            case .rest:
                return .rest
            case .planComplete:
                return .planComplete
            case .missed(let mw, let md, let cw, let cd):
                if let cw, let cd {
                    return .missedChoice(missedWeek: mw, missedDay: md, todayWeek: cw, todayDay: cd)
                }
                return .session(week: mw, day: md, makeup: true)
            }
        }
    }

    /// Whether the parked starting session `(week, day)` has already been logged
    /// *today* — once it has, Today falls back to the normal flow instead of
    /// re-offering it.
    private static func parkedLoggedToday(_ week: Int, _ day: Int,
                                         _ completions: [CompletionRecord],
                                         _ today: Date, _ calendar: Calendar) -> Bool {
        completions.contains {
            guard let c = $0.workoutCoordinate else { return false }
            return c.week == week && c.day == day && calendar.isDate($0.date, inSameDayAs: today)
        }
    }
}

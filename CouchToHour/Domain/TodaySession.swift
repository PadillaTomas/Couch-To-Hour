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

    /// Every session is done.
    case planComplete

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

        switch mode {
        case .free:
            let next = FreeProgression.nextDay(in: plan, startingWeek: startingWeek,
                                               startingDay: startingDay) { day in
                DoneDetection.isComplete(day, among: completions)
            }
            guard let next, let week = next.week?.number else { return .planComplete }
            return .session(week: week, day: next.number, makeup: false)

        case .threeDay:
            let slots = ScheduleGenerator.schedule(startingWeek: startingWeek,
                                                   startingDay: startingDay,
                                                   startDate: startDate ?? today,
                                                   calendar: calendar)

            // The session the runner parked the plan at shows on its scheduled
            // day even if it was completed before — they explicitly chose to
            // (re)start here. Once they log it *today*, it drops back to the
            // normal "done for today" flow.
            let parkedDoneToday = completions.contains {
                guard let c = $0.workoutCoordinate else { return false }
                return c.week == startingWeek && c.day == startingDay
                    && calendar.isDate($0.date, inSameDayAs: today)
            }
            if !parkedDoneToday, slots.contains(where: {
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
}

import Foundation

/// The single resolved view of where the runner stands: the four inputs from
/// `UserSettings` plus the plan and history, with every screen's derived data
/// hanging off it.
///
/// Build one per view from the `@Query` results (``from(settings:plans:completions:today:calendar:)``)
/// and read `currentSession` / `schedule` / `month(containing:)` / `dayInfo(for:)`
/// / `overview` from it. **Nothing else re-derives "where am I" or "when is the
/// schedule" — that duplication is exactly what let Today and Calendar disagree.**
struct PlanState {
    let mode: TrainingMode
    let startingWeek: Int
    let startingDay: Int
    let startDate: Date?
    /// The instant the current plan instance began (`UserSettings.planEpoch`).
    let planEpoch: Date
    let plan: WorkoutPlan
    /// Every completion record ever logged — the permanent history. Progression
    /// and the plan overview use ``planCompletions``; the calendar's done dots
    /// use this directly.
    let completions: [CompletionRecord]
    let today: Date
    let calendar: Calendar

    /// The completions that drive *progression* for the current plan instance:
    /// those logged at or after ``planEpoch``. Records from a previous plan (or
    /// DEBUG demo data) are kept forever and still show on the calendar as done,
    /// but they don't pre-complete the current plan — a reconfigure decides the
    /// future from the new schedule.
    var planCompletions: [CompletionRecord] {
        completions.filter { $0.date >= planEpoch }
    }

    /// The dated schedule. Never stored — derived here and nowhere else.
    ///
    /// - 3-Day: the full generated grid from the start date.
    /// - Free: at most one slot — the current session on its start date, and
    ///   only while that date is still today or ahead (Free has no dated grid,
    ///   just "one thing to aim at").
    var schedule: [ScheduleGenerator.Slot] {
        switch mode {
        case .threeDay:
            return ScheduleGenerator.schedule(startingWeek: startingWeek,
                                              startingDay: startingDay,
                                              startDate: startDate ?? today,
                                              calendar: calendar)
        case .free:
            guard let startDate,
                  calendar.startOfDay(for: startDate) >= calendar.startOfDay(for: today)
            else { return [] }
            let coord = currentSession.coordinate ?? (week: startingWeek, day: startingDay)
            return [ScheduleGenerator.Slot(week: coord.week, day: coord.day,
                                           date: calendar.startOfDay(for: startDate))]
        }
    }

    /// What the Today tab shows right now. The one resolver.
    var currentSession: TodaySession {
        TodaySession.resolve(mode: mode, plan: plan,
                             startingWeek: startingWeek, startingDay: startingDay,
                             startDate: startDate, completions: planCompletions,
                             today: today, calendar: calendar)
    }

    /// The calendar keeps **every** done session visible for all time; only the
    /// scheduled ("pending") dots come from the current plan's derived schedule,
    /// so a reconfigure replaces the pending dots wholesale without touching the
    /// done history.
    func month(containing date: Date) -> CalendarMonth {
        CalendarMonth.resolve(monthContaining: date, schedule: schedule,
                              completions: completions, today: today, calendar: calendar)
    }

    func dayInfo(for date: Date) -> CalendarDayInfo {
        CalendarDayInfo.resolve(date: date, plan: plan, schedule: schedule,
                                completions: completions, today: today, calendar: calendar)
    }

    var overview: PlanOverview {
        PlanOverview.resolve(plan: plan, startingWeek: startingWeek, completions: planCompletions)
    }
}

extension PlanState {
    /// Build from a view's `@Query` results. `nil` until the singleton
    /// `UserSettings` / `WorkoutPlan` rows exist (first launch, before seeding).
    static func from(settings: [UserSettings],
                     plans: [WorkoutPlan],
                     completions: [CompletionRecord],
                     today: Date = .now,
                     calendar: Calendar = .current) -> PlanState? {
        guard let s = settings.first, let plan = plans.first else { return nil }
        return PlanState(mode: s.mode,
                         startingWeek: s.startingWeek,
                         startingDay: s.startingDay,
                         startDate: s.startDate,
                         planEpoch: s.planEpoch,
                         plan: plan,
                         completions: completions,
                         today: today,
                         calendar: calendar)
    }
}

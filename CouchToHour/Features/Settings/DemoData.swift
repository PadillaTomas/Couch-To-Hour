#if DEBUG
import Foundation
import SwiftData

/// DEBUG-only: put the app into a realistic mid-plan state so the Calendar and
/// Today have data to click through, without running sessions by hand.
enum DemoData {

    /// A fully populated **3-Day** state: the schedule is anchored ~2.5 weeks in
    /// the past, so the Calendar shows completed sessions behind and scheduled
    /// sessions ahead, with "today" landing around Week 3.
    static func loadThreeDay(into context: ModelContext, now: Date = .now) {
        guard let plan = try? context.fetch(FetchDescriptor<WorkoutPlan>()).first else { return }
        clear(from: context)

        let calendar = Calendar.current
        let anchor = calendar.date(byAdding: .day, value: -18, to: calendar.startOfDay(for: now))!

        ScheduleGenerator.apply(to: plan, startingWeek: 1, startDate: anchor, calendar: calendar)

        // Complete every session whose scheduled date is already in the past.
        let ratings = [5, 6, 5, 7, 6, 8, 6, 7, 6, 7]
        var index = 0
        for day in plan.orderedWeeks.flatMap(\.orderedDays) {
            guard let scheduled = day.scheduledDate,
                  scheduled < calendar.startOfDay(for: now) else { continue }
            context.insert(CompletionRecord(
                date: scheduled,
                workoutDayKey: day.completionKey,
                durationSeconds: SessionPlan(day: day).totalSeconds,
                feltRating: ratings[index % ratings.count]
            ))
            index += 1
        }

        let settings = UserSettings.current(in: context)
        settings.mode = .threeDay
        settings.startWeekday = calendar.component(.weekday, from: anchor)
        settings.startingWeek = 1
        settings.startingDay = 1
        settings.startDate = anchor
        settings.onboardingCompleted = true

        try? context.save()
    }

    static func clear(from context: ModelContext) {
        for record in (try? context.fetch(FetchDescriptor<CompletionRecord>())) ?? [] {
            context.delete(record)
        }
        if let plan = try? context.fetch(FetchDescriptor<WorkoutPlan>()).first {
            ScheduleGenerator.clearSchedule(for: plan)
        }
        try? context.save()
    }
}
#endif

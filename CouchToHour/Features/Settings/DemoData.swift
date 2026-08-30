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
        let schedule = ScheduleGenerator.schedule(startingWeek: 1, startDate: anchor,
                                                  calendar: calendar)

        // Complete every session whose scheduled date is already in the past.
        let ratings = [5, 6, 5, 7, 6, 8, 6, 7, 6, 7]
        for (index, slot) in schedule.enumerated()
        where slot.date < calendar.startOfDay(for: now) {
            guard let day = plan.day(week: slot.week, day: slot.day) else { continue }
            context.insert(CompletionRecord(
                date: slot.date,
                workoutDayKey: day.completionKey,
                durationSeconds: SessionPlan(day: day).totalSeconds,
                feltRating: ratings[index % ratings.count]
            ))
        }

        let settings = UserSettings.current(in: context)
        settings.mode = .threeDay
        settings.startWeekday = calendar.component(.weekday, from: anchor)
        settings.startingWeek = 1
        settings.startingDay = 1
        settings.startDate = anchor
        settings.planEpoch = anchor   // this "instance" began when the demo schedule did
        settings.onboardingCompleted = true

        try? context.save()
    }

    static func clear(from context: ModelContext) {
        for record in (try? context.fetch(FetchDescriptor<CompletionRecord>())) ?? [] {
            if let photo = record.photoPath { PhotoStore.delete(photo) }
            context.delete(record)
        }
        try? context.save()
    }
}
#endif

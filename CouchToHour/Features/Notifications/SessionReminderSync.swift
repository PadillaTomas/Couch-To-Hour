import Foundation
import SwiftData
import UserNotifications

/// Keeps the pending local notifications in step with the plan. Call after any
/// change to the schedule, the mode, the toggle, or completions — and on launch.
enum SessionReminderSync {

    /// Reconcile the pending session reminders with the current state.
    ///
    /// - 3-Day + toggle on + authorized → pending set becomes exactly the
    ///   upcoming, not-yet-done sessions.
    /// - Anything else (Free mode, toggle off, permission not granted) → every
    ///   session reminder is cleared.
    ///
    /// Never prompts — the Settings toggle owns the permission prompt; this just
    /// respects the answer.
    static func reconcile(plan: WorkoutPlan?,
                          settings: UserSettings,
                          completions: [CompletionRecord],
                          center: any UserNotificationScheduling,
                          now: Date = .now,
                          calendar: Calendar = .current) async {
        var wanted: [SessionReminder] = []
        if settings.notificationsEnabled,
           settings.mode == .threeDay,
           let plan,
           await center.alertAuthorizationStatus() == .authorized {
            let schedule = ScheduleGenerator.schedule(
                startingWeek: settings.startingWeek,
                startingDay: settings.startingDay,
                startDate: settings.startDate ?? now,
                calendar: calendar)
            // Only the current plan instance's completions dismiss a reminder —
            // a session done under a previous plan is still "to do" now.
            let planCompletions = completions.filter { $0.date >= settings.planEpoch }
            wanted = SessionReminder.upcoming(schedule: schedule, plan: plan,
                                              completions: planCompletions,
                                              now: now, calendar: calendar)
        }

        let stale = await center.pendingSessionReminderIDs()
        if !stale.isEmpty { center.removeSessionReminders(ids: stale) }
        for reminder in wanted {
            await center.scheduleSessionReminder(request(for: reminder))
        }
    }

    /// A same-calendar-day, non-repeating notification for `reminder`.
    static func request(for reminder: SessionReminder,
                        calendar: Calendar = .current) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = Copy.Reminders.notificationTitle(week: reminder.week, day: reminder.day)
        content.body = Copy.Reminders.notificationBody(minutes: reminder.minutes,
                                                       summary: reminder.summary)
        content.sound = .default

        let fields = calendar.dateComponents([.year, .month, .day, .hour, .minute],
                                             from: reminder.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: fields, repeats: false)
        return UNNotificationRequest(identifier: reminder.identifier,
                                     content: content, trigger: trigger)
    }
}

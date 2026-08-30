import Foundation

/// One pending local reminder for a dated 3-Day session: which session, and the
/// exact moment its notification should fire. Pure value — the
/// `UNUserNotificationCenter` side lives in ``SessionReminderSync``.
struct SessionReminder: Equatable {
    var week: Int
    var day: Int
    /// Date + time-of-day the notification fires.
    var fireDate: Date
    /// One-line session shape, e.g. "1 min run / 1 min walk ×10".
    var summary: String
    /// Whole-minute session length, for the notification body.
    var minutes: Int

    /// Stable per session so a reschedule replaces cleanly rather than stacking.
    var identifier: String { Self.identifier(week: week, day: day) }
    static func identifier(week: Int, day: Int) -> String { "\(identifierPrefix)W\(week)D\(day)" }
    /// Every session-reminder id starts with this — used to clear the whole set.
    static let identifierPrefix = "cth.session."

    /// Fixed reminder time-of-day. Not user-configurable yet (CTH-14 scope).
    static let defaultHour = 7
    static let defaultMinute = 0
}

extension SessionReminder {
    /// The reminders that *should* be pending, given the current dated schedule.
    ///
    /// One per scheduled slot that is **still ahead** (`fireDate > now`) and
    /// **not already done**. Callers gate on 3-Day mode and the settings toggle —
    /// this only does the date maths.
    static func upcoming(schedule: [ScheduleGenerator.Slot],
                         plan: WorkoutPlan,
                         completions: [CompletionRecord],
                         hour: Int = defaultHour,
                         minute: Int = defaultMinute,
                         now: Date = .now,
                         calendar: Calendar = .current) -> [SessionReminder] {
        var result: [SessionReminder] = []
        for slot in schedule {
            guard let day = plan.day(week: slot.week, day: slot.day),
                  !DoneDetection.isComplete(day, among: completions),
                  let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0,
                                           of: slot.date),
                  fire > now
            else { continue }
            result.append(SessionReminder(
                week: slot.week,
                day: slot.day,
                fireDate: fire,
                summary: SessionPlan.summary(of: day),
                minutes: SessionPlan(day: day).totalSeconds / 60
            ))
        }
        return result.sorted { $0.fireDate < $1.fireDate }
    }
}

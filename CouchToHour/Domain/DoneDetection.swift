import Foundation
import SwiftData

/// Marking a `WorkoutDay` complete — manually ("mark Done") or automatically
/// when the timer reaches the end of the session — and asking whether a day is
/// already done.
enum DoneDetection {

    /// Records a completion for `day`, unless one was already logged for it on
    /// the same calendar day — so the manual button and the timer's auto-complete
    /// can't double-log a single session, but re-doing a workout on another day
    /// (e.g. after restarting the plan) logs a fresh record.
    ///
    /// - Parameters:
    ///   - durationSeconds: time the session actually took; defaults to the
    ///     plan's scheduled running + walking total.
    ///   - feltRating: usually `nil` here — the post-workout screen fills it in
    ///     afterwards via ``CompletionRecord/feltRating``.
    /// - Returns: the new record, or `nil` if `day` was already logged today.
    @discardableResult
    static func markComplete(_ day: WorkoutDay,
                             on date: Date,
                             durationSeconds: Int? = nil,
                             feltRating: Int? = nil,
                             calendar: Calendar = .current,
                             in context: ModelContext) -> CompletionRecord? {
        let key = day.completionKey
        let existing = (try? context.fetch(FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { $0.workoutDayKey == key }
        ))) ?? []
        if existing.contains(where: { calendar.isDate($0.date, inSameDayAs: date) }) { return nil }

        let record = CompletionRecord(
            date: date,
            workoutDayKey: key,
            durationSeconds: durationSeconds ?? SessionPlan(day: day).totalSeconds,
            feltRating: feltRating
        )
        context.insert(record)
        return record
    }

    static func isComplete(week: Int, day: Int, among records: [CompletionRecord]) -> Bool {
        let key = WorkoutDay.completionKey(week: week, day: day)
        return records.contains { $0.workoutDayKey == key }
    }

    static func isComplete(_ day: WorkoutDay, among records: [CompletionRecord]) -> Bool {
        records.contains { $0.workoutDayKey == day.completionKey }
    }
}

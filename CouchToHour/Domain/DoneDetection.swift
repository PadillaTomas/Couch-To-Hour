import Foundation
import SwiftData

/// Marking a `WorkoutDay` complete — manually ("mark Done") or automatically
/// when the timer reaches the end of the session — and asking whether a day is
/// already done.
enum DoneDetection {

    /// Records a completion for `day` unless it already has one. Idempotent, so
    /// the manual button and the timer's auto-complete can't double-log.
    ///
    /// - Parameters:
    ///   - durationSeconds: time the session actually took; defaults to the
    ///     plan's scheduled running + walking total.
    ///   - feltRating: usually `nil` here — the post-workout screen fills it in
    ///     afterwards via ``CompletionRecord/feltRating``.
    /// - Returns: the new record, or `nil` if the day was already complete.
    @discardableResult
    static func markComplete(_ day: WorkoutDay,
                             on date: Date,
                             durationSeconds: Int? = nil,
                             feltRating: Int? = nil,
                             in context: ModelContext) -> CompletionRecord? {
        let key = day.completionKey
        var descriptor = FetchDescriptor<CompletionRecord>(
            predicate: #Predicate { $0.workoutDayKey == key }
        )
        descriptor.fetchLimit = 1
        if (try? context.fetch(descriptor))?.isEmpty == false { return nil }

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

import Foundation
import SwiftData
import UIWorkouts

/// The fixed 6-week program: `WorkoutPlan → WorkoutWeek → WorkoutDay → Interval`.
/// Seeded once at first launch (see ``PlanSeed``) and never edited by the user —
/// the taper/peak/recover sequencing is the point.
@Model
final class WorkoutPlan {
    /// Stable identifier for the one fixed plan. Not a `.unique` attribute —
    /// SwiftData's unique constraints trap on in-memory stores (used by the
    /// tests), and ``PlanSeed`` already guards against a second plan.
    var slug: String
    var title: String

    @Relationship(deleteRule: .cascade, inverse: \WorkoutWeek.plan)
    var weeks: [WorkoutWeek] = []

    init(slug: String = WorkoutPlan.fixedSlug, title: String = "1h Run — 6 Week Plan") {
        self.slug = slug
        self.title = title
    }

    static let fixedSlug = "couch-to-hour-6week-v1"

    /// Weeks 1…6 in ascending order.
    var orderedWeeks: [WorkoutWeek] { weeks.sorted { $0.number < $1.number } }

    /// The `WorkoutDay` at a `(week, day)` coordinate, or `nil` if out of range.
    func day(week: Int, day: Int) -> WorkoutDay? {
        orderedWeeks.first { $0.number == week }?.orderedDays.first { $0.number == day }
    }
}

@Model
final class WorkoutWeek {
    /// 1…6.
    var number: Int
    var plan: WorkoutPlan?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutDay.week)
    var days: [WorkoutDay] = []

    init(number: Int) {
        self.number = number
    }

    /// Days D1…D3 in ascending order.
    var orderedDays: [WorkoutDay] { days.sorted { $0.number < $1.number } }
}

@Model
final class WorkoutDay {
    var week: WorkoutWeek?
    /// 1…3 — D1 / D2 / D3.
    var number: Int

    /// Concrete calendar date in 3-Day mode; `nil` in Free mode (and before
    /// onboarding runs schedule generation).
    var scheduledDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \Interval.day)
    var intervals: [Interval] = []

    init(number: Int, scheduledDate: Date? = nil) {
        self.number = number
        self.scheduledDate = scheduledDate
    }

    /// The raw plan-notation blocks in play order. Expand with ``SessionPlan``
    /// to get the literal phase sequence a timer plays.
    var orderedIntervals: [Interval] { intervals.sorted { $0.order < $1.order } }

    /// Stable `"W3D2"`-style identity used by ``CompletionRecord`` so completion
    /// history survives a store rebuild.
    var completionKey: String { WorkoutDay.completionKey(week: week?.number ?? 0, day: number) }

    static func completionKey(week: Int, day: Int) -> String { "W\(week)D\(day)" }
}

@Model
final class Interval {
    var day: WorkoutDay?
    /// Position within the session, ascending.
    var order: Int
    /// Groups the two halves of one `(R a / W b) ×N` chunk: the run and the walk
    /// of the same chunk share this value. The "then" in "×1, then ×5" starts a
    /// new group. A chunk with no walk (W6D3) has only a run in its group.
    var group: Int
    /// ``WKPhase`` raw value — stored as `String` so the persisted store never
    /// depends on a UIWorkouts type. Read through ``phase``.
    var phaseRaw: String
    var durationSeconds: Int
    /// How many times this group's run/walk pair repeats.
    var repeatCount: Int

    init(order: Int, group: Int, phase: WKPhase, durationSeconds: Int, repeatCount: Int) {
        self.order = order
        self.group = group
        self.phaseRaw = phase.rawValue
        self.durationSeconds = durationSeconds
        self.repeatCount = repeatCount
    }

    /// Computed — the `@Model` macro leaves it out of the persisted schema.
    var phase: WKPhase {
        get { WKPhase(rawValue: phaseRaw) ?? .run }
        set { phaseRaw = newValue.rawValue }
    }
}

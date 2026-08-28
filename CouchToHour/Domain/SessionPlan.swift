import Foundation
import UIWorkouts

/// A `WorkoutDay` flattened into the literal ordered phase sequence a timer
/// plays. This is where the two plan-data edge cases are resolved:
///
/// 1. **A session never ends on a walk.** Every plan chunk is `run` then a
///    1-minute recovery walk, so all but W6D3 would otherwise end mid-recovery.
///    The trailing walk of the final chunk is dropped — the session is complete
///    when the last *run* ends. (Interior walks are always followed by the next
///    chunk's run, so only the very last phase can ever be a walk.)
/// 2. **A chunk with no walk** (W6D3) contributes a single continuous run.
struct SessionPlan: Equatable {
    struct Phase: Equatable {
        var phase: WKPhase
        var seconds: Int
    }

    var phases: [Phase]

    var totalSeconds: Int { phases.reduce(0) { $0 + $1.seconds } }
    /// Time actually held running — the number the app is really about.
    var runningSeconds: Int {
        phases.filter { $0.phase == .run }.reduce(0) { $0 + $1.seconds }
    }
}

extension SessionPlan {
    /// One `(R / W) ×N` block of a day, for the grouped session list.
    struct Group: Equatable, Identifiable {
        var id: Int
        var runSeconds: Int
        var walkSeconds: Int?
        var repeatCount: Int
    }

    /// The day's intervals collapsed back into their `(R / W) ×N` blocks — the
    /// shape the plan is written in, rather than the flattened phase list.
    static func groups(of day: WorkoutDay) -> [Group] {
        let byGroup = Dictionary(grouping: day.orderedIntervals, by: \.group)
        return byGroup.keys.sorted().map { key in
            let members = byGroup[key]!
            return Group(
                id: key,
                runSeconds: members.first { $0.phase == .run }?.durationSeconds ?? 0,
                walkSeconds: members.first { $0.phase == .walk }?.durationSeconds,
                repeatCount: members.map(\.repeatCount).max() ?? 1
            )
        }
    }

    /// A few seconds per phase — the DEBUG "fast timer" on Today uses this to
    /// walk the timer → rating flow without waiting out real durations.
    static let fastTest = SessionPlan(phases: [
        .init(phase: .run, seconds: 5),
        .init(phase: .walk, seconds: 3),
        .init(phase: .run, seconds: 5),
    ])

    init(day: WorkoutDay) {
        self.init(intervals: day.orderedIntervals)
    }

    init(intervals: [Interval]) {
        var result: [Phase] = []
        let groups = Dictionary(grouping: intervals, by: \.group)

        for key in groups.keys.sorted() {
            let members = groups[key]!.sorted { $0.order < $1.order }
            let run = members.first { $0.phase == .run }
            let walk = members.first { $0.phase == .walk }
            let repeats = members.map(\.repeatCount).max() ?? 1

            for _ in 0..<repeats {
                if let run { result.append(Phase(phase: .run, seconds: run.durationSeconds)) }
                if let walk { result.append(Phase(phase: .walk, seconds: walk.durationSeconds)) }
            }
        }

        // Edge case 1: trim a trailing recovery walk.
        if result.last?.phase == .walk { result.removeLast() }

        self.phases = result
    }
}

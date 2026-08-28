import Foundation
import SwiftData
import UIWorkouts

/// Builds the fixed 6-week plan graph on first launch, idempotently.
///
/// Source of truth: the plan table on *Couch to Hour — Modules & Delivery Plan*
/// (Confluence page 5832706). All blueprint durations are **minutes**;
/// `Segment(run:walk:repeats:)` is one `(R run / W walk) ×repeats` chunk, and a
/// `nil` walk is a chunk with no walk interval at all (W6D3).
enum PlanSeed {

    struct Segment {
        let runMinutes: Int
        let walkMinutes: Int?
        let repeats: Int

        init(run: Int, walk: Int?, repeats: Int = 1) {
            self.runMinutes = run
            self.walkMinutes = walk
            self.repeats = repeats
        }
    }

    /// Weeks 1…6, each three days (D1…D3), each an ordered list of chunks.
    static let blueprint: [[[Segment]]] = [
        [   // Week 1
            [Segment(run: 1, walk: 1, repeats: 10)],
            [Segment(run: 1, walk: 1), Segment(run: 2, walk: 1, repeats: 5)],
            [Segment(run: 2, walk: 1, repeats: 10)],
        ],
        [   // Week 2
            [Segment(run: 2, walk: 1), Segment(run: 3, walk: 1, repeats: 5)],
            [Segment(run: 3, walk: 1, repeats: 10)],
            [Segment(run: 3, walk: 1), Segment(run: 5, walk: 1, repeats: 3)],
        ],
        [   // Week 3
            [Segment(run: 5, walk: 1, repeats: 6)],
            [Segment(run: 5, walk: 1), Segment(run: 10, walk: 1, repeats: 2)],
            [Segment(run: 10, walk: 1, repeats: 3)],
        ],
        [   // Week 4
            [Segment(run: 10, walk: 1), Segment(run: 15, walk: 1), Segment(run: 10, walk: 1)],
            [Segment(run: 15, walk: 1), Segment(run: 10, walk: 1), Segment(run: 15, walk: 1)],
            [Segment(run: 15, walk: 1, repeats: 3)],
        ],
        [   // Week 5
            [Segment(run: 10, walk: 1), Segment(run: 20, walk: 1), Segment(run: 10, walk: 1)],
            [Segment(run: 10, walk: 1), Segment(run: 25, walk: 1), Segment(run: 10, walk: 1)],
            [Segment(run: 10, walk: 1), Segment(run: 30, walk: 1), Segment(run: 10, walk: 1)],
        ],
        [   // Week 6
            [Segment(run: 5, walk: 1), Segment(run: 40, walk: 1)],
            [Segment(run: 10, walk: 1), Segment(run: 30, walk: 1), Segment(run: 10, walk: 1)],
            [Segment(run: 50, walk: nil)],
        ],
    ]

    /// Inserts the plan graph if it is not already present. Safe to call on
    /// every launch — a second call with the plan already seeded is a no-op.
    static func seed(into context: ModelContext) {
        // There is only ever one plan — a plain fetch is enough, and avoids a
        // #Predicate that can misbehave on an in-memory store.
        var descriptor = FetchDescriptor<WorkoutPlan>()
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor), !existing.isEmpty { return }

        let plan = WorkoutPlan()
        context.insert(plan)

        for (weekIndex, week) in blueprint.enumerated() {
            let weekModel = WorkoutWeek(number: weekIndex + 1)
            weekModel.plan = plan
            plan.weeks.append(weekModel)
            context.insert(weekModel)

            for (dayIndex, day) in week.enumerated() {
                let dayModel = WorkoutDay(number: dayIndex + 1)
                dayModel.week = weekModel
                weekModel.days.append(dayModel)
                context.insert(dayModel)

                var order = 0
                for (groupIndex, segment) in day.enumerated() {
                    let run = Interval(order: order, group: groupIndex, phase: .run,
                                       durationSeconds: segment.runMinutes * 60,
                                       repeatCount: segment.repeats)
                    run.day = dayModel
                    dayModel.intervals.append(run)
                    context.insert(run)
                    order += 1

                    if let walk = segment.walkMinutes {
                        let walkInterval = Interval(order: order, group: groupIndex, phase: .walk,
                                                    durationSeconds: walk * 60,
                                                    repeatCount: segment.repeats)
                        walkInterval.day = dayModel
                        dayModel.intervals.append(walkInterval)
                        context.insert(walkInterval)
                        order += 1
                    }
                }
            }
        }
    }
}

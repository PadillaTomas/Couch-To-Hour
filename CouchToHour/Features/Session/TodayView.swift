import SwiftData
import SwiftUI
import UIWorkouts

/// The Today / Up-Next tab: resolves the current session from mode + schedule +
/// history, shows its interval list, and drives the timer → rating flow.
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [UserSettings]
    @Query private var plans: [WorkoutPlan]
    @Query(sort: \CompletionRecord.date) private var completions: [CompletionRecord]

    @State private var flow: Flow?
    /// Which side of an Option-C prompt the user picked.
    @State private var missedPick: MissedPick?

    private enum MissedPick { case missed, today }

    private enum Flow: Identifiable {
        /// `fast` compresses the plan to a few seconds per phase — DEBUG only,
        /// for walking the screen flow without waiting out real durations.
        case timer(WorkoutDay, fast: Bool)
        case rating(CompletionRecord)
        var id: String {
            switch self {
            case .timer(let d, let fast): return "timer-\(d.persistentModelID.hashValue)-\(fast)"
            case .rating(let r): return "rating-\(r.persistentModelID.hashValue)"
            }
        }
    }

    private var settings: UserSettings? { settingsRows.first }
    private var plan: WorkoutPlan? { plans.first }

    private var session: TodaySession? {
        guard let settings, let plan else { return nil }
        return TodaySession.resolve(
            mode: settings.mode,
            plan: plan,
            startingWeek: settings.startingWeek,
            startWeekday: settings.startWeekday,
            startDate: settings.startDate,
            completions: completions,
            today: .now
        )
    }

    var body: some View {
        ZStack {
            WKColor.bg.ignoresSafeArea()
            content
        }
        .fullScreenCover(item: $flow) { flow in
            switch flow {
            case .timer(let day, let fast):
                TimerView(
                    plan: fast ? .fastTest : SessionPlan(day: day),
                    onFinish: { elapsed in finish(day, elapsedSeconds: elapsed) },
                    onExit: { self.flow = nil }
                )
            case .rating(let record):
                PostWorkoutView(record: record, onDone: { self.flow = nil })
            }
        }
    }

    @ViewBuilder private var content: some View {
        if let session {
            switch session {
            case .session(let week, let day, let makeup):
                dayScreen(week: week, day: day, makeup: makeup)
            case .missedChoice(let mw, let md, let tw, let td):
                switch missedPick {
                case .missed: dayScreen(week: mw, day: md, makeup: true)
                case .today:  dayScreen(week: tw, day: td, makeup: false)
                case nil:     missedPrompt(missedWeek: mw, missedDay: md)
                }
            case .rest:
                infoScreen(eyebrow: "Today", title: "Rest day",
                           detail: "Nothing scheduled. See you on your next session day.")
            case .planComplete:
                infoScreen(eyebrow: "Today", title: "Plan complete",
                           detail: "You went from the couch to a full hour. That's the whole thing.")
            }
        } else {
            infoScreen(eyebrow: "Today", title: "Setting things up…", detail: nil)
        }
    }

    // MARK: Screens

    @ViewBuilder
    private func dayScreen(week: Int, day: Int, makeup: Bool) -> some View {
        if let workoutDay = plan?.day(week: week, day: day) {
            let sessionPlan = SessionPlan(day: workoutDay)
            ScrollView {
                VStack(alignment: .leading, spacing: WKSpace.xl) {
                    WKScreenHeader(
                        eyebrow: makeup ? "Making up a missed session" : "Today",
                        title: "Week \(week) · Day \(day)",
                        body: "\(sessionPlan.totalSeconds / 60) min · \(runCount(sessionPlan)) run intervals"
                    )
                    WKSegmentedTrack(segments: previewTrack(sessionPlan))
                    VStack(spacing: WKSpace.sm) {
                        ForEach(SessionPlan.groups(of: workoutDay)) { group in
                            WKIntervalGroup(runSeconds: group.runSeconds,
                                            walkSeconds: group.walkSeconds,
                                            repeatCount: group.repeatCount)
                        }
                    }
                }
                .padding(WKSpace.lg)
            }
            .safeAreaInset(edge: .bottom) {
                WKFooterActions {
                    WKButton("Start session") { flow = .timer(workoutDay, fast: false) }
                    WKButton("Mark done", style: .quiet) { markDone(workoutDay) }
                    #if DEBUG
                    WKButton("Test: fast timer", style: .quiet) {
                        flow = .timer(workoutDay, fast: true)
                    }
                    #endif
                }
            }
        } else {
            infoScreen(eyebrow: "Today", title: "Week \(week) · Day \(day)", detail: nil)
        }
    }

    @ViewBuilder
    private func missedPrompt(missedWeek: Int, missedDay: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKSpace.xl) {
                WKScreenHeader(
                    eyebrow: "Missed session",
                    title: "You missed Week \(missedWeek) · Day \(missedDay)",
                    body: "Do it now, or pick up with today's session. No rush either way."
                )
                VStack(spacing: WKSpace.md) {
                    WKChoiceCard(title: "Do the missed session",
                                 body: "Week \(missedWeek) · Day \(missedDay)",
                                 isSelected: false) { missedPick = .missed }
                    WKChoiceCard(title: "Continue with today's session",
                                 isSelected: false) { missedPick = .today }
                }
            }
            .padding(WKSpace.lg)
        }
    }

    @ViewBuilder
    private func infoScreen(eyebrow: String, title: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: WKSpace.xl) {
            WKScreenHeader(eyebrow: eyebrow, title: title, body: detail)
            Spacer()
        }
        .padding(WKSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Actions

    private func markDone(_ day: WorkoutDay) {
        let record = DoneDetection.markComplete(day, on: .now, in: context)
        try? context.save()
        missedPick = nil
        if let record { flow = .rating(record) }
    }

    private func finish(_ day: WorkoutDay, elapsedSeconds: Int) {
        let record = DoneDetection.markComplete(day, on: .now,
                                                durationSeconds: elapsedSeconds, in: context)
        try? context.save()
        missedPick = nil
        flow = record.map(Flow.rating)
    }

    // MARK: Helpers

    private func runCount(_ plan: SessionPlan) -> Int {
        plan.phases.filter { $0.phase == .run }.count
    }

    private func previewTrack(_ plan: SessionPlan) -> [WKTrackSegment] {
        plan.phases.enumerated().map { index, phase in
            WKTrackSegment(id: index, weight: Double(phase.seconds),
                           progress: .upcoming, phase: phase.phase)
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(for: UserSettings.self, inMemory: true)
}

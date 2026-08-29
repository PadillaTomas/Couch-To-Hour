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
        /// `resume` picks up a persisted in-progress session for this day.
        case timer(WorkoutDay, key: SessionKey, fast: Bool, resume: Bool)
        case rating(CompletionRecord)
        var id: String {
            switch self {
            case .timer(let d, let key, let fast, let resume):
                return "timer-\(d.persistentModelID.hashValue)-\(key.week)-\(key.day)-\(key.makeup)-\(fast)-\(resume)"
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
            startingDay: settings.startingDay,
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
            case .timer(let day, let key, let fast, let resume):
                TimerView(
                    plan: fast ? .fastTest : SessionPlan(day: day),
                    key: key,
                    resume: resume ? SessionResumeStore.load() : nil,
                    dimsOtherAudio: settings?.dimOtherAudioDuringCues ?? true,
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
                infoScreen(eyebrow: Copy.Today.eyebrow, title: Copy.Today.restDayTitle,
                           detail: Copy.Today.restDayBody)
            case .notStartedYet(let date):
                infoScreen(eyebrow: Copy.Today.eyebrow, title: Copy.Today.notStartedTitle,
                           detail: Copy.Today.notStartedBody(
                            date: date.formatted(.dateTime.weekday(.wide).month().day())))
            case .planComplete:
                infoScreen(eyebrow: Copy.Today.eyebrow, title: Copy.Today.planCompleteTitle,
                           detail: Copy.Today.planCompleteBody)
            }
        } else {
            infoScreen(eyebrow: Copy.Today.eyebrow, title: Copy.Today.settingUp, detail: nil)
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
                        eyebrow: makeup ? Copy.Today.makeupEyebrow : Copy.Today.eyebrow,
                        title: Copy.Today.dayTitle(week: week, day: day),
                        body: Copy.Today.daySubtitle(minutes: sessionPlan.totalSeconds / 60,
                                                     summary: SessionPlan.summary(of: workoutDay))
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
                let key = SessionKey(week: week, day: day, makeup: makeup)
                let canResume = SessionResumeStore.load()?.key == key
                WKFooterActions {
                    if canResume {
                        WKButton(Copy.Today.actionResume) {
                            flow = .timer(workoutDay, key: key, fast: false, resume: true)
                        }
                        WKButton(Copy.Today.actionStartOver, style: .quiet) {
                            SessionResumeStore.clear()
                            flow = .timer(workoutDay, key: key, fast: false, resume: false)
                        }
                    } else {
                        WKButton(Copy.Today.actionStart) {
                            SessionResumeStore.clear()
                            flow = .timer(workoutDay, key: key, fast: false, resume: false)
                        }
                    }
                    WKButton(Copy.Today.actionMarkDone, style: .quiet) { markDone(workoutDay) }
                    #if DEBUG
                    WKButton("Test: fast timer", style: .quiet) {
                        flow = .timer(workoutDay, key: key, fast: true, resume: false)
                    }
                    #endif
                }
            }
        } else {
            infoScreen(eyebrow: Copy.Today.eyebrow,
                       title: Copy.Today.dayTitle(week: week, day: day), detail: nil)
        }
    }

    @ViewBuilder
    private func missedPrompt(missedWeek: Int, missedDay: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKSpace.xl) {
                WKScreenHeader(
                    eyebrow: Copy.Today.missedEyebrow,
                    title: Copy.Today.missedTitle(week: missedWeek, day: missedDay),
                    body: Copy.Today.missedBody
                )
                VStack(spacing: WKSpace.md) {
                    WKChoiceCard(title: Copy.Today.missedDoTitle,
                                 body: Copy.Today.missedDoBody(week: missedWeek, day: missedDay),
                                 isSelected: false) { missedPick = .missed }
                    WKChoiceCard(title: Copy.Today.missedContinueTodayTitle,
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
        context.saveChanges("session marked done")
        missedPick = nil
        if let record { flow = .rating(record) }
    }

    private func finish(_ day: WorkoutDay, elapsedSeconds: Int) {
        let record = DoneDetection.markComplete(day, on: .now,
                                                durationSeconds: elapsedSeconds, in: context)
        context.saveChanges("session finished")
        missedPick = nil
        flow = record.map(Flow.rating)
    }

    // MARK: Helpers

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

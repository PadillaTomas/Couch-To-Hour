import SwiftData
import SwiftUI
import UIWorkouts

/// Read-only browse of the whole 6-week plan — every week, every day, tap a day
/// to see its interval breakdown. Presented as a sheet from Settings ("Training
/// plan") and from onboarding ("See all workouts").
///
/// `showsProgress` is off for the onboarding browse (there's no history yet and
/// the starting week isn't chosen), on from Settings.
struct PlanOverviewView: View {
    var showsProgress: Bool = true
    /// When set, the browser is in "pick a workout" mode: each expanded day gets
    /// a "Start from here" button that calls this with its `(week, day)`.
    var onSelectDay: ((_ week: Int, _ day: Int) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Query private var plans: [WorkoutPlan]
    @Query private var settingsRows: [UserSettings]
    @Query(sort: \CompletionRecord.date) private var completions: [CompletionRecord]

    @State private var expanded: Set<String> = []

    private var overview: PlanOverview? {
        guard let plan = plans.first else { return nil }
        // From Settings: the runner's real progress, via the shared PlanState so
        // it's scoped to the current plan instance (same as Today / Calendar).
        // From onboarding: a plain browse of the whole plan, no progress.
        if showsProgress, let state = PlanState.from(settings: settingsRows, plans: plans,
                                                     completions: completions) {
            return state.overview
        }
        return PlanOverview.resolve(plan: plan, startingWeek: 1, completions: [])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WKSpace.xl) {
                    WKScreenHeader(title: onSelectDay == nil ? Copy.PlanOverview.title
                                                             : Copy.PlanSetup.fromSpecificTitle,
                                   body: Copy.PlanOverview.body)

                    if let overview {
                        ForEach(overview.weeks) { week in
                            VStack(alignment: .leading, spacing: WKSpace.md) {
                                WKSectionHeader(Copy.PlanOverview.weekLabel(week.number))
                                ForEach(week.days) { day in
                                    dayCard(day)
                                }
                            }
                        }
                    }
                }
                .padding(WKSpace.lg)
            }
            .background(WKColor.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.PlanOverview.close) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCard(_ day: PlanOverview.Day) -> some View {
        let isOpen = expanded.contains(day.id)
        WKCard {
            VStack(alignment: .leading, spacing: WKSpace.sm) {
                Button {
                    withAnimation(.snappy) {
                        if isOpen { expanded.remove(day.id) } else { expanded.insert(day.id) }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: WKSpace.xs) {
                        HStack {
                            Text(Copy.PlanOverview.dayLabel(day.day))
                                .wkFont(.headline)
                                .foregroundStyle(WKColor.textPrimary)
                            Spacer(minLength: WKSpace.sm)
                            statusPill(day.state)
                            Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(WKColor.textTertiary)
                        }
                        Text(Copy.PlanOverview.minutes(day.totalSeconds / 60))
                            .wkFont(.body)
                            .foregroundStyle(WKColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isOpen {
                    WKSegmentedTrack(segments: track(day))
                        .padding(.top, WKSpace.xs)
                    VStack(spacing: WKSpace.xs) {
                        ForEach(day.groups) { group in
                            WKIntervalGroup(runSeconds: group.runSeconds,
                                            walkSeconds: group.walkSeconds,
                                            repeatCount: group.repeatCount)
                        }
                    }
                    if let onSelectDay {
                        WKButton(Copy.PlanSetup.startFromHere, style: .primary, size: .compact) {
                            onSelectDay(day.week, day.day)
                        }
                        .padding(.top, WKSpace.xs)
                    }
                }
            }
        }
        .opacity(day.state == .beforeStart && onSelectDay == nil ? 0.55 : 1)
    }

    @ViewBuilder
    private func statusPill(_ state: PlanOverview.DayState) -> some View {
        switch state {
        case .done where showsProgress:
            WKPill(Copy.PlanOverview.statusDone, tone: .done)
        case .next where showsProgress:
            WKPill(Copy.PlanOverview.statusNext, tone: .run)
        default:
            EmptyView()
        }
    }

    private func track(_ day: PlanOverview.Day) -> [WKTrackSegment] {
        day.phases.enumerated().map { index, phase in
            WKTrackSegment(id: index,
                           weight: Double(phase.seconds),
                           progress: day.state == .done ? .done : .upcoming,
                           phase: phase.phase)
        }
    }
}

#Preview("From Settings") {
    PlanOverviewView()
        .modelContainer(for: UserSettings.self, inMemory: true)
}

#Preview("From onboarding") {
    PlanOverviewView(showsProgress: false)
        .modelContainer(for: UserSettings.self, inMemory: true)
}

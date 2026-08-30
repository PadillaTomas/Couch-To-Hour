import SwiftData
import SwiftUI
import UIWorkouts

/// The Calendar tab: a month grid with dots on completed / scheduled days.
/// Tapping a day selects it and shows what that session was (or will be) below.
struct CalendarView: View {
    @Query private var settingsRows: [UserSettings]
    @Query private var plans: [WorkoutPlan]
    @Query(sort: \CompletionRecord.date) private var completions: [CompletionRecord]

    @State private var monthAnchor = Date()
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)

    private var calendar: Calendar { .current }

    private var planState: PlanState? {
        PlanState.from(settings: settingsRows, plans: plans, completions: completions)
    }

    private var month: CalendarMonth {
        planState?.month(containing: monthAnchor)
            ?? CalendarMonth.resolve(monthContaining: monthAnchor, schedule: [],
                                     completions: completions, today: .now, calendar: calendar)
    }

    /// Day-of-month to ring in the grid — nil when the selection is in another month.
    private var selectionDay: Int? {
        guard calendar.isDate(selectedDate, equalTo: monthAnchor, toGranularity: .month) else { return nil }
        return calendar.component(.day, from: selectedDate)
    }

    private var info: CalendarDayInfo {
        planState?.dayInfo(for: selectedDate) ?? .rest
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKSpace.xl) {
                WKMonthGrid(
                    monthTitle: month.title,
                    weekdaySymbols: month.weekdaySymbols,
                    leadingBlanks: month.leadingBlanks,
                    days: month.days.map { WKDay(id: $0.id, day: $0.number, state: $0.state) },
                    selection: selectionDay,
                    onStep: step,
                    onSelect: select
                )

                Divider().overlay(WKColor.border)

                detailPanel
            }
            .padding(WKSpace.lg)
        }
        .background(WKColor.bg.ignoresSafeArea())
        .animation(.snappy, value: selectedDate)
    }

    @ViewBuilder private var detailPanel: some View {
        VStack(alignment: .leading, spacing: WKSpace.md) {
            Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .wkFont(.labelMono)
                .foregroundStyle(WKColor.textTertiary)

            switch info {
            case .sessions(let items):
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    sessionBlock(item)
                }
            case .rest:
                Text(Copy.Calendar.nothingScheduled)
                    .wkFont(.body).foregroundStyle(WKColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func sessionBlock(_ item: CalendarDayInfo.Item) -> some View {
        VStack(alignment: .leading, spacing: WKSpace.sm) {
            HStack(alignment: .firstTextBaseline, spacing: WKSpace.md) {
                Text(Copy.Calendar.dayTitle(week: item.week, day: item.day))
                    .wkFont(.titleM).foregroundStyle(WKColor.textPrimary)
                if case .scheduled(let isToday) = item.status {
                    WKPill(isToday ? Copy.Calendar.pillToday : Copy.Calendar.pillScheduled,
                           tone: isToday ? .run : .neutral)
                }
            }
            if case .done(let seconds, let rating) = item.status {
                HStack(spacing: WKSpace.xxl) {
                    stat(Copy.Calendar.statTime, WKTimeFormat.clock(seconds))
                    if let rating { stat(Copy.Calendar.statFelt, Copy.Calendar.feltValue(rating)) }
                    stat(Copy.Calendar.statStatus, Copy.Calendar.statusDone)
                }
            }
            intervals(item.groups, done: item.isDone)
        }
        .padding(.top, WKSpace.xs)
    }

    private func intervals(_ groups: [SessionPlan.Group], done: Bool) -> some View {
        VStack(alignment: .leading, spacing: WKSpace.xs) {
            ForEach(groups) { group in
                Text(group.line)
                    .wkFont(.body)
                    .monospacedDigit()
                    .foregroundStyle(done ? WKColor.textTertiary : WKColor.textSecondary)
            }
        }
        .padding(.top, WKSpace.sm)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).wkFont(.caption).foregroundStyle(WKColor.textTertiary)
            Text(value).wkFont(.headline).foregroundStyle(WKColor.textPrimary)
        }
    }

    private func step(_ delta: Int) {
        if let moved = calendar.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = moved
        }
    }

    private func select(_ wkDay: WKDay) {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthAnchor))!
        if let picked = calendar.date(byAdding: .day, value: wkDay.day - 1, to: monthStart) {
            selectedDate = picked
        }
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: UserSettings.self, inMemory: true)
}

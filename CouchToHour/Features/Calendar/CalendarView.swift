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
    private var mode: TrainingMode { settingsRows.first?.mode ?? .threeDay }

    private var month: CalendarMonth {
        CalendarMonth.resolve(monthContaining: monthAnchor, mode: mode, plan: plans.first,
                              completions: completions, today: .now, calendar: calendar)
    }

    /// Day-of-month to ring in the grid — nil when the selection is in another month.
    private var selectionDay: Int? {
        guard calendar.isDate(selectedDate, equalTo: monthAnchor, toGranularity: .month) else { return nil }
        return calendar.component(.day, from: selectedDate)
    }

    private var info: CalendarDayInfo {
        CalendarDayInfo.resolve(date: selectedDate, mode: mode, plan: plans.first,
                                completions: completions, today: .now, calendar: calendar)
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
            case let .done(week, day, groups, seconds, rating):
                Text("Week \(week) · Day \(day)")
                    .wkFont(.titleM).foregroundStyle(WKColor.textPrimary)
                HStack(spacing: WKSpace.xxl) {
                    stat("Time", WKTimeFormat.clock(seconds))
                    if let rating { stat("Felt", "\(rating) / 10") }
                    stat("Status", "Done")
                }
                intervals(groups, done: true)

            case let .scheduled(week, day, groups, isToday):
                HStack(alignment: .firstTextBaseline, spacing: WKSpace.md) {
                    Text("Week \(week) · Day \(day)")
                        .wkFont(.titleM).foregroundStyle(WKColor.textPrimary)
                    WKPill(isToday ? "Today" : "Scheduled", tone: isToday ? .run : .neutral)
                }
                intervals(groups, done: false)

            case .rest:
                Text("Nothing scheduled.")
                    .wkFont(.body).foregroundStyle(WKColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

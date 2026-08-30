import SwiftData
import SwiftUI
import UIKit
import UIWorkouts

/// The Calendar tab: a month grid with dots on completed / scheduled days.
/// Tapping a day selects it and lists that day's sessions as compact rows; tap a
/// row for the full detail in a sheet.
struct CalendarView: View {
    @Query private var settingsRows: [UserSettings]
    @Query private var plans: [WorkoutPlan]
    @Query(sort: \CompletionRecord.date) private var completions: [CompletionRecord]

    @State private var monthAnchor = Date()
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var openSession: CalendarDayInfo.Item?

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
        .sheet(item: $openSession) { item in
            SessionDetailSheet(item: item)
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder private var detailPanel: some View {
        VStack(alignment: .leading, spacing: WKSpace.md) {
            Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .wkFont(.labelMono)
                .foregroundStyle(WKColor.textTertiary)

            switch info {
            case .sessions(let items):
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        if item.id != items.first?.id {
                            Divider().overlay(WKColor.border)
                        }
                        sessionRow(item)
                    }
                }
                .background(WKColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: WKRadius.card, style: .continuous))
            case .rest:
                Text(Copy.Calendar.nothingScheduled)
                    .wkFont(.body).foregroundStyle(WKColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sessionRow(_ item: CalendarDayInfo.Item) -> some View {
        Button { openSession = item } label: {
            HStack(spacing: WKSpace.sm) {
                Text(Copy.Calendar.dayTitle(week: item.week, day: item.day))
                    .wkFont(.body)
                    .foregroundStyle(WKColor.textPrimary)

                Spacer(minLength: WKSpace.sm)

                switch item.status {
                case .done(_, let rating, let photoFile):
                    if photoFile != nil {
                        Image(systemName: "photo")
                            .font(.system(size: 13))
                            .foregroundStyle(WKColor.textTertiary)
                    }
                    Text(rating.map(Copy.Calendar.feltValue) ?? Copy.Calendar.statusDone)
                        .wkFont(.body)
                        .foregroundStyle(WKColor.textSecondary)
                case .scheduled(let isToday):
                    WKPill(isToday ? Copy.Calendar.pillToday : Copy.Calendar.pillScheduled,
                           tone: isToday ? .run : .neutral)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WKColor.textTertiary)
            }
            .frame(minHeight: 52)
            .padding(.horizontal, WKSpace.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

// MARK: - Session detail sheet

/// The full breakdown of one calendar session — the content that used to sit
/// inline in the day panel: stats, the interval list, and (last) the photo.
private struct SessionDetailSheet: View {
    let item: CalendarDayInfo.Item

    @State private var viewerImage: ViewerImage?

    private struct ViewerImage: Identifiable { let id = UUID(); let image: UIImage }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKSpace.xl) {
                HStack(alignment: .firstTextBaseline, spacing: WKSpace.md) {
                    Text(Copy.Calendar.dayTitle(week: item.week, day: item.day))
                        .wkFont(.titleM).foregroundStyle(WKColor.textPrimary)
                    if case .scheduled(let isToday) = item.status {
                        WKPill(isToday ? Copy.Calendar.pillToday : Copy.Calendar.pillScheduled,
                               tone: isToday ? .run : .neutral)
                    }
                }

                if case .done(let seconds, let rating, _) = item.status {
                    HStack(spacing: WKSpace.xxl) {
                        stat(Copy.Calendar.statTime, WKTimeFormat.clock(seconds))
                        if let rating { stat(Copy.Calendar.statFelt, Copy.Calendar.feltValue(rating)) }
                        stat(Copy.Calendar.statStatus, Copy.Calendar.statusDone)
                    }
                }

                intervals(item.groups, done: item.isDone)

                if case .done(_, _, let photoFile) = item.status, let photoFile {
                    SessionPhoto(fileName: photoFile) { viewerImage = ViewerImage(image: $0) }
                }
            }
            .padding(.horizontal, WKSpace.xl)
            .padding(.top, WKSpace.xl)
            .padding(.bottom, WKSpace.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(WKColor.bg.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .fullScreenCover(item: $viewerImage) { entry in
            PhotoViewer(image: entry.image) { viewerImage = nil }
        }
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
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).wkFont(.caption).foregroundStyle(WKColor.textTertiary)
            Text(value).wkFont(.headline).foregroundStyle(WKColor.textPrimary)
        }
    }
}

/// A stored session photo. Shows a placeholder while loading, the image once
/// ready, or an "unavailable" state if the file behind `fileName` can't be read.
private struct SessionPhoto: View {
    let fileName: String
    var onTap: (UIImage) -> Void

    @State private var image: UIImage?
    @State private var loaded = false

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .task(id: fileName) {
                image = PhotoStore.load(fileName)
                loaded = true
            }
    }

    @ViewBuilder private var content: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: WKRadius.card, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture { onTap(image) }
                .accessibilityLabel(Copy.PostWorkout.photoAlt)
                .accessibilityAddTraits(.isButton)
        } else if loaded {
            HStack(spacing: WKSpace.sm) {
                Image(systemName: "photo")
                Text(Copy.Calendar.photoUnavailable)
            }
            .wkFont(.caption)
            .foregroundStyle(WKColor.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(WKColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: WKRadius.card, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: WKRadius.card, style: .continuous)
                .fill(WKColor.surface)
                .frame(height: 200)
                .overlay(ProgressView())
        }
    }
}

/// Full-screen viewer for a session photo — tap or the close button to dismiss.
private struct PhotoViewer: View {
    let image: UIImage
    var onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityLabel(Copy.PostWorkout.photoAlt)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(WKSpace.sm)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .padding(WKSpace.lg)
            .accessibilityLabel(Copy.PhotoViewer.close)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onClose)
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: UserSettings.self, inMemory: true)
}

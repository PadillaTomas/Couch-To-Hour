import SwiftData
import SwiftUI
import UIWorkouts
import UserNotifications

/// The app root: runs onboarding until it's completed, then the tab shell. The
/// persisted theme is applied exactly once, here.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @Query private var plans: [WorkoutPlan]
    @Query private var completions: [CompletionRecord]

    private var current: UserSettings? { settings.first }

    /// Anything that changes the desired reminder set collapses to this — the
    /// `.task` below re-reconciles whenever it moves (launch, plan reconfigure,
    /// a session logged, the toggle).
    private var reminderStateKey: String {
        let s = current
        return [s?.modeRaw ?? "",
                String(s?.notificationsEnabled ?? false),
                String(s?.startDate?.timeIntervalSince1970 ?? 0),
                String(s?.planEpoch.timeIntervalSince1970 ?? 0),
                String(completions.count)].joined(separator: "|")
    }

    var body: some View {
        Group {
            if current?.onboardingCompleted == true {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        .tint(WKColor.accent)
        .wkThemeMode(current?.themeMode ?? .system)
        .task(id: reminderStateKey) {
            // Runs on launch and whenever the desired set moves. Reconcile also
            // covers the "clear everything" cases (toggle off, Free mode, a
            // reset that re-armed onboarding), so it isn't gated on the gate.
            guard !isRunningInPreview, let settings = current else { return }
            await SessionReminderSync.reconcile(
                plan: plans.first,
                settings: settings,
                completions: completions,
                center: UNUserNotificationCenter.current())
        }
    }
}

private let isRunningInPreview =
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

/// The 3-tab bar (Today / Calendar / Settings) hosting placeholder screens.
struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label(Copy.Tabs.today, systemImage: "figure.run") }
            CalendarView()
                .tabItem { Label(Copy.Tabs.calendar, systemImage: "calendar") }
            SettingsView()
                .tabItem { Label(Copy.Tabs.settings, systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: UserSettings.self, inMemory: true)
}

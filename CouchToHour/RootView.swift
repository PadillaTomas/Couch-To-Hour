import SwiftData
import SwiftUI
import UIWorkouts

/// The app root: runs onboarding until it's completed, then the tab shell. The
/// persisted theme is applied exactly once, here.
struct RootView: View {
    @Query private var settings: [UserSettings]

    private var current: UserSettings? { settings.first }

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
    }
}

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

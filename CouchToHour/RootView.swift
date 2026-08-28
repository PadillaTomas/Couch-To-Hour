import SwiftData
import SwiftUI
import UIWorkouts

/// The app shell: a 3-tab bar (Today / Calendar / Settings) hosting placeholder
/// screens. The persisted theme is applied exactly once, here at the root.
struct RootView: View {
    @Query private var settings: [UserSettings]

    private var themeMode: WKThemeMode { settings.first?.themeMode ?? .system }

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "figure.run") }
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(WKColor.accent)
        .wkThemeMode(themeMode)
    }
}

#Preview {
    RootView()
        .modelContainer(for: UserSettings.self, inMemory: true)
}

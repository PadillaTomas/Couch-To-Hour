import SwiftData
import SwiftUI
import UIWorkouts

/// Settings screen: the theme picker bound to the persisted `UserSettings`, plus
/// placeholder nav rows for options that later modules fill in.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKSpace.xl) {
                WKScreenHeader(title: "Settings")

                VStack(alignment: .leading, spacing: WKSpace.md) {
                    WKSectionHeader("Appearance")
                    WKThemePicker(selection: themeBinding)
                }

                VStack(alignment: .leading, spacing: WKSpace.md) {
                    WKSectionHeader("Plan")
                    VStack(spacing: 0) {
                        WKNavRow("Training plan", value: "6-week") {}
                        Divider().overlay(WKColor.border)
                        WKNavRow("Schedule", value: "Not set") {}
                    }
                    .background(WKColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: WKRadius.card, style: .continuous))
                }

                Text("UIWorkouts \(UIWorkouts.version)")
                    .wkFont(.caption)
                    .foregroundStyle(WKColor.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(WKSpace.lg)
        }
        .background(WKColor.bg.ignoresSafeArea())
    }

    private var themeBinding: Binding<WKThemeMode> {
        Binding(
            get: { settings.first?.themeMode ?? .system },
            set: { UserSettings.current(in: modelContext).themeMode = $0 }
        )
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: UserSettings.self, inMemory: true)
}

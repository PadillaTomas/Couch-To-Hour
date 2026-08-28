import SwiftData
import SwiftUI
import UIWorkouts

/// Settings screen: the theme picker bound to the persisted `UserSettings`, plus
/// placeholder nav rows for options that later modules fill in, and a full
/// reset.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]

    @State private var showResetDialog = false

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
            }
            .padding(WKSpace.lg)
        }
        .background(WKColor.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { resetFooter }
        .alert("Reset the app?", isPresented: $showResetDialog) {
            Button("Reset", role: .destructive) {
                AppReset.performFullReset(in: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes your completed sessions and schedule. This can't be undone.")
        }
    }

    /// Pinned above the tab bar: a red "Reset" and one line saying what it does.
    private var resetFooter: some View {
        VStack(spacing: WKSpace.xs) {
            // Plain text button — no capsule frame, so it hugs its caption.
            Button("Reset") { showResetDialog = true }
                .wkFont(.body)
                .foregroundStyle(WKColor.danger)

            Text("Deletes your completed sessions and schedule.")
                .wkFont(.caption)
                .foregroundStyle(WKColor.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, WKSpace.lg)
        .padding(.top, WKSpace.sm)
        .padding(.bottom, WKSpace.xxl)   // separation from the tab bar
        .background(WKColor.bg)
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

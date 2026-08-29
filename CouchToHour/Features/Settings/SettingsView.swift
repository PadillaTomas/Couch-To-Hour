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
                WKScreenHeader(title: Copy.Settings.title)

                VStack(alignment: .leading, spacing: WKSpace.md) {
                    WKSectionHeader(Copy.Settings.appearance)
                    WKThemePicker(selection: themeBinding)
                }

                VStack(alignment: .leading, spacing: WKSpace.xs) {
                    WKSectionHeader(Copy.Settings.plan)
                    VStack(spacing: 0) {
                        // TODO: opens a plan-mode switcher (→ Free) — separate ticket.
                        WKNavRow(Copy.Settings.trainingPlanRow, value: Copy.Settings.trainingPlanValue) {}
                        Divider().overlay(WKColor.border)
                        WKNavRow(Copy.Settings.scheduleRow, value: Copy.Settings.scheduleValueNotSet) {}
                    }
                    .background(WKColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: WKRadius.card, style: .continuous))
                    SeeAllWorkoutsLink(showsProgress: true)
                }

                VStack(alignment: .leading, spacing: WKSpace.md) {
                    WKSectionHeader(Copy.Settings.audio)
                    VStack(spacing: 0) {
                        WKToggleRow(Copy.Settings.dimOtherAudio, isOn: dimAudioBinding)
                    }
                    .background(WKColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: WKRadius.card, style: .continuous))
                    Text(Copy.Settings.dimOtherAudioCaption)
                        .wkFont(.caption)
                        .foregroundStyle(WKColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                #if DEBUG
                VStack(alignment: .leading, spacing: WKSpace.md) {
                    WKSectionHeader("Debug")
                    WKButton("Load demo (3-Day, mid-plan)", style: .secondary) {
                        DemoData.loadThreeDay(into: modelContext)
                    }
                    Text("3-Day mode, schedule anchored ~2.5 weeks back: past sessions completed, future ones scheduled. Reset to clear.")
                        .wkFont(.caption)
                        .foregroundStyle(WKColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                #endif
            }
            .padding(WKSpace.lg)
        }
        .background(WKColor.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { resetFooter }
        .alert(Copy.Settings.resetAlertTitle, isPresented: $showResetDialog) {
            Button(Copy.Settings.resetAlertConfirm, role: .destructive) {
                AppReset.performFullReset(in: modelContext)
            }
            Button(Copy.Settings.resetAlertCancel, role: .cancel) {}
        } message: {
            Text(Copy.Settings.resetAlertBody)
        }
    }

    /// Pinned above the tab bar: a red "Reset" and one line saying what it does.
    private var resetFooter: some View {
        VStack(spacing: WKSpace.xs) {
            // Plain text button — no capsule frame, so it hugs its caption.
            Button(Copy.Settings.resetButton) { showResetDialog = true }
                .wkFont(.body)
                .foregroundStyle(WKColor.danger)

            Text(Copy.Settings.resetFooterCaption)
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

    private var dimAudioBinding: Binding<Bool> {
        Binding(
            get: { settings.first?.dimOtherAudioDuringCues ?? true },
            set: { UserSettings.current(in: modelContext).dimOtherAudioDuringCues = $0 }
        )
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: UserSettings.self, inMemory: true)
}

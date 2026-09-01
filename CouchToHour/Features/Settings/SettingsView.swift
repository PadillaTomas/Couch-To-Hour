import SwiftData
import SwiftUI
import UIKit
import UIWorkouts
import UserNotifications

/// Settings screen: plan / audio / reminder groups and a full reset.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]

    @State private var showResetDialog = false
    @State private var showSetupAlert = false
    @State private var showSetupFlow = false
    @State private var showReminderDeniedAlert = false

    private var mode: TrainingMode { settings.first?.mode ?? .threeDay }

    private var scheduleValue: String {
        guard mode == .threeDay, let weekday = settings.first?.startWeekday else {
            return Copy.Settings.scheduleNotUsed
        }
        return Copy.Settings.scheduleStartsWeekday(Calendar.current.weekdaySymbols[weekday - 1])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKSpace.xl) {
                WKScreenHeader(title: Copy.Settings.title)

                VStack(alignment: .leading, spacing: WKSpace.md) {
                    WKSectionHeader(Copy.Settings.appearance)
                    WKThemePicker(selection: appearanceBinding, options: [
                        (.system, Copy.Settings.appearanceSystem),
                        (.light, Copy.Settings.appearanceLight),
                        (.dark, Copy.Settings.appearanceDark),
                    ])
                }

                VStack(alignment: .leading, spacing: WKSpace.xs) {
                    WKInsetGroup(header: Copy.Settings.plan) {
                        WKNavRow(Copy.Settings.trainingPlanRow,
                                 value: Copy.Settings.modeName(mode)) {
                            showSetupAlert = true
                        }
                        WKNavRow(Copy.Settings.scheduleRow, value: scheduleValue) {
                            showSetupAlert = true
                        }
                    }
                    SeeAllWorkoutsLink(showsProgress: true)
                }

                WKInsetGroup(header: Copy.Settings.audio,
                             footer: Copy.Settings.dimOtherAudioCaption) {
                    WKToggleRow(Copy.Settings.dimOtherAudio, isOn: dimAudioBinding)
                }

                if mode == .threeDay {
                    WKInsetGroup(header: Copy.Settings.reminders,
                                 footer: Copy.Settings.remindersCaption) {
                        WKToggleRow(Copy.Settings.remindersToggle, isOn: remindersBinding)
                    }
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
        .alert(Copy.Settings.switchModeTitle, isPresented: $showSetupAlert) {
            Button(Copy.Onboarding.footerContinue) { showSetupFlow = true }
            Button(Copy.Settings.resetAlertCancel, role: .cancel) {}
        } message: {
            Text(Copy.Settings.switchModeBody)
        }
        .sheet(isPresented: $showSetupFlow) { PlanReconfigureSheet() }
        .alert(Copy.Settings.remindersDeniedTitle, isPresented: $showReminderDeniedAlert) {
            Button(Copy.Settings.remindersDeniedOpenSettings) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(Copy.Settings.remindersDeniedCancel, role: .cancel) {}
        } message: {
            Text(Copy.Settings.remindersDeniedBody)
        }
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

    private var appearanceBinding: Binding<WKAppearance> {
        Binding(
            get: { settings.first?.appearance ?? .dark },
            set: {
                UserSettings.current(in: modelContext).appearance = $0
                modelContext.saveChanges("appearance")
            }
        )
    }

    private var dimAudioBinding: Binding<Bool> {
        Binding(
            get: { settings.first?.dimOtherAudioDuringCues ?? true },
            set: { UserSettings.current(in: modelContext).dimOtherAudioDuringCues = $0 }
        )
    }

    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { settings.first?.notificationsEnabled ?? false },
            set: { handleRemindersToggle($0) }
        )
    }

    /// Persist the toggle, then: turning on asks for notification permission
    /// (flipping back off + pointing at iOS Settings if it's denied); either way
    /// the pending reminders are reconciled to match.
    private func handleRemindersToggle(_ on: Bool) {
        UserSettings.current(in: modelContext).notificationsEnabled = on
        modelContext.saveChanges("reminder toggle")

        guard on else {
            Task { await reconcileReminders() }
            return
        }
        Task {
            let center = UNUserNotificationCenter.current()
            var status = await center.alertAuthorizationStatus()
            if status == .notDetermined {
                _ = await center.requestAlertAuthorization()
                status = await center.alertAuthorizationStatus()
            }
            guard status == .authorized else {
                UserSettings.current(in: modelContext).notificationsEnabled = false
                modelContext.saveChanges("reminder permission denied")
                showReminderDeniedAlert = true
                return
            }
            await reconcileReminders()
        }
    }

    private func reconcileReminders() async {
        await SessionReminderSync.reconcile(
            plan: try? modelContext.fetch(FetchDescriptor<WorkoutPlan>()).first,
            settings: UserSettings.current(in: modelContext),
            completions: (try? modelContext.fetch(FetchDescriptor<CompletionRecord>())) ?? [],
            center: UNUserNotificationCenter.current())
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: UserSettings.self, inMemory: true)
}

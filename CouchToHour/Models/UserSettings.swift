import Foundation
import SwiftData
import UIWorkouts

/// Which way the user runs the plan.
enum TrainingMode: String, CaseIterable, Sendable {
    /// Dated schedule: sessions land on concrete calendar dates.
    case threeDay
    /// No schedule: work through D1→D2→D3 of each week at your own cadence.
    case free
}

/// Single-row app settings. CTH-4 added the appearance choice; CTH-5 adds the
/// mode / schedule fields the engine needs. All new fields are defaulted so the
/// first-launch row and the CTH-4 store both migrate cleanly.
@Model
final class UserSettings {
    /// Raw value of the selected ``WKThemeMode``. Stored as `String` so the
    /// persisted store never depends on a UIWorkouts type. Read/written through
    /// ``themeMode``.
    var themeModeRaw: String

    /// Raw value of the selected ``TrainingMode``. Read through ``mode``.
    /// Defaults are declared here (not just in `init`) so SwiftData lightweight
    /// migration can add these columns to the existing CTH-4 store.
    var modeRaw: String = TrainingMode.threeDay.rawValue

    /// `Calendar` weekday the training week starts on, 1 (Sunday)…7 (Saturday).
    /// Used only in 3-Day mode.
    var startWeekday: Int = 2

    /// Plan week the user begins at, 1…6 — lets an experienced runner skip ahead.
    var startingWeek: Int = 1

    /// Plan day within ``startingWeek`` the user begins at, 1…3. Lets the setup
    /// flow drop you mid-week ("start from Week 3 · Day 2").
    var startingDay: Int = 1

    /// Anchor date the plan counts forward from. In 3-Day it's what the schedule
    /// is generated from; in Free it's the optional first-run date (or `nil`).
    var startDate: Date?

    /// Placeholder for MVP+ local reminders. Unused in Step 1.
    var notificationsEnabled: Bool = false

    /// Briefly dip other apps' audio (music, podcasts) under each timer cue so
    /// the click is audible over it. Off = cues layer on top at full volume.
    /// A device preference, not workout data — kept across a reset.
    var dimOtherAudioDuringCues: Bool = true

    /// First-run gate. `false` until onboarding finishes; once `true`, relaunch
    /// goes straight to the app.
    var onboardingCompleted: Bool = false

    init(themeMode: WKThemeMode = .system,
         mode: TrainingMode = .threeDay,
         startWeekday: Int = 2,
         startingWeek: Int = 1,
         startDate: Date? = nil,
         notificationsEnabled: Bool = false,
         dimOtherAudioDuringCues: Bool = true,
         onboardingCompleted: Bool = false) {
        self.themeModeRaw = themeMode.rawValue
        self.modeRaw = mode.rawValue
        self.startWeekday = startWeekday
        self.startingWeek = startingWeek
        self.startDate = startDate
        self.notificationsEnabled = notificationsEnabled
        self.dimOtherAudioDuringCues = dimOtherAudioDuringCues
        self.onboardingCompleted = onboardingCompleted
    }

    /// Computed — the `@Model` macro leaves it out of the persisted schema.
    var themeMode: WKThemeMode {
        get { WKThemeMode(rawValue: themeModeRaw) ?? .system }
        set { themeModeRaw = newValue.rawValue }
    }

    var mode: TrainingMode {
        get { TrainingMode(rawValue: modeRaw) ?? .threeDay }
        set { modeRaw = newValue.rawValue }
    }

    /// Puts every plan/schedule field back to its first-run default and re-arms
    /// the onboarding gate. The appearance theme is deliberately kept — it isn't
    /// workout data.
    func resetToFirstRun() {
        mode = .threeDay
        startWeekday = 2
        startingWeek = 1
        startingDay = 1
        startDate = nil
        notificationsEnabled = false
        onboardingCompleted = false
    }
}

extension UserSettings {
    /// Returns the singleton settings row, creating and inserting it the first
    /// time it is asked for. Idempotent — safe to call from any screen.
    @discardableResult
    static func current(in context: ModelContext) -> UserSettings {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = UserSettings()
        context.insert(created)
        return created
    }
}

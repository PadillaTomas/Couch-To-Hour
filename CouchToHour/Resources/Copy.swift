import Foundation

/// Typed access to every user-facing string, backed by the **`Localizable.xcstrings`
/// String Catalog** (edit copy there, or in Xcode's catalog editor).
///
/// Why a thin wrapper instead of `Text("literal")` everywhere: the UIWorkouts
/// components take plain `String`, not `LocalizedStringKey`, so a call site has
/// to resolve the string itself. Centralising that here keeps the keys in one
/// list and the call sites clean (`Copy.Timer.endSession`).
///
/// Interpolated entries pass a `defaultValue` — that English format is a *fallback*
/// only; the catalog value for the same key wins at runtime. See `LOCALIZATION.md`.
enum Copy {

    enum Tabs {
        static var today: String { String(localized: "tabs.today") }
        static var calendar: String { String(localized: "tabs.calendar") }
        static var settings: String { String(localized: "tabs.settings") }
    }

    enum Onboarding {
        static var modeEyebrow: String { String(localized: "onboarding.mode.eyebrow") }
        static var modeTitle: String { String(localized: "onboarding.mode.title") }
        static var modeBody: String { String(localized: "onboarding.mode.body") }
        static var threeDayTitle: String { String(localized: "onboarding.mode.threeDayTitle") }
        static var threeDayBody: String { String(localized: "onboarding.mode.threeDayBody") }
        static var freeTitle: String { String(localized: "onboarding.mode.freeTitle") }
        static var freeBody: String { String(localized: "onboarding.mode.freeBody") }

        static var startingWeekTitle: String { String(localized: "onboarding.startingWeek.title") }
        static var startingWeekBody: String { String(localized: "onboarding.startingWeek.body") }
        static func weekLabel(_ n: Int) -> String {
            String(localized: "onboarding.startingWeek.weekLabel", defaultValue: "Week \(n)")
        }
        /// One-line blurb per plan week, index 0 = Week 1.
        static var weekBlurbs: [String] {
            [String(localized: "onboarding.startingWeek.blurb1"),
             String(localized: "onboarding.startingWeek.blurb2"),
             String(localized: "onboarding.startingWeek.blurb3"),
             String(localized: "onboarding.startingWeek.blurb4"),
             String(localized: "onboarding.startingWeek.blurb5"),
             String(localized: "onboarding.startingWeek.blurb6")]
        }


        static var philosophyTitle: String { String(localized: "onboarding.philosophy.title") }
        static var philosophyBody1: String { String(localized: "onboarding.philosophy.body1") }
        static var philosophyBody2: String { String(localized: "onboarding.philosophy.body2") }

        static var footerContinue: String { String(localized: "onboarding.footer.continue") }
        static var footerStart: String { String(localized: "onboarding.footer.start") }
        static var footerBack: String { String(localized: "onboarding.footer.back") }
    }

    enum Today {
        static var eyebrow: String { String(localized: "today.eyebrow") }
        static var makeupEyebrow: String { String(localized: "today.makeupEyebrow") }
        static func dayTitle(week: Int, day: Int) -> String {
            String(localized: "today.dayTitle", defaultValue: "Week \(week) · Day \(day)")
        }
        static func daySubtitle(minutes: Int, summary: String) -> String {
            String(localized: "today.daySubtitle", defaultValue: "\(minutes) min · \(summary)")
        }
        static var settingUp: String { String(localized: "today.settingUp") }
        static var notStartedTitle: String { String(localized: "today.notStartedTitle") }
        static func notStartedBody(date: String) -> String {
            String(localized: "today.notStartedBody", defaultValue: "Your plan starts \(date). See you then.")
        }
        static var restDayTitle: String { String(localized: "today.restDay.title") }
        static var restDayBody: String { String(localized: "today.restDay.body") }
        static var planCompleteTitle: String { String(localized: "today.planComplete.title") }
        static var planCompleteBody: String { String(localized: "today.planComplete.body") }

        static var actionStart: String { String(localized: "today.actions.start") }
        static var actionResume: String { String(localized: "today.actions.resume") }
        static var actionStartOver: String { String(localized: "today.actions.startOver") }
        static var actionMarkDone: String { String(localized: "today.actions.markDone") }

        static var missedEyebrow: String { String(localized: "today.missed.eyebrow") }
        static func missedTitle(week: Int, day: Int) -> String {
            String(localized: "today.missed.title", defaultValue: "You missed Week \(week) · Day \(day)")
        }
        static var missedBody: String { String(localized: "today.missed.body") }
        static var missedDoTitle: String { String(localized: "today.missed.doMissedTitle") }
        static func missedDoBody(week: Int, day: Int) -> String {
            String(localized: "today.missed.doMissedBody", defaultValue: "Week \(week) · Day \(day)")
        }
        static var missedContinueTodayTitle: String { String(localized: "today.missed.continueTodayTitle") }
    }

    enum Timer {
        static var runCaption: String { String(localized: "timer.runCaption") }
        static var walkCaption: String { String(localized: "timer.walkCaption") }
        static var pause: String { String(localized: "timer.pause") }
        static var resume: String { String(localized: "timer.resume") }
        static var endSession: String { String(localized: "timer.endSession") }
        static var endConfirmTitle: String { String(localized: "timer.endConfirm.title") }
        static var endConfirmConfirm: String { String(localized: "timer.endConfirm.confirm") }
        static var endConfirmCancel: String { String(localized: "timer.endConfirm.cancel") }
        static var endConfirmBody: String { String(localized: "timer.endConfirm.body") }
    }

    enum PostWorkout {
        static var eyebrow: String { String(localized: "postWorkout.eyebrow") }
        static var title: String { String(localized: "postWorkout.title") }
        static var body: String { String(localized: "postWorkout.body") }
        static var easyLabel: String { String(localized: "postWorkout.easyLabel") }
        static var hardLabel: String { String(localized: "postWorkout.hardLabel") }
        static var addPhoto: String { String(localized: "postWorkout.addPhoto") }
        static var takePhoto: String { String(localized: "postWorkout.takePhoto") }
        static var chooseFromLibrary: String { String(localized: "postWorkout.chooseFromLibrary") }
        static var changePhoto: String { String(localized: "postWorkout.changePhoto") }
        static var removePhoto: String { String(localized: "postWorkout.removePhoto") }
        static var photoAlt: String { String(localized: "postWorkout.photoAlt") }
        static var cameraDeniedTitle: String { String(localized: "postWorkout.cameraDeniedTitle") }
        static var cameraDeniedBody: String { String(localized: "postWorkout.cameraDeniedBody") }
        static var openSettings: String { String(localized: "postWorkout.openSettings") }
        static var notNow: String { String(localized: "postWorkout.notNow") }
        static var save: String { String(localized: "postWorkout.save") }
        static var skip: String { String(localized: "postWorkout.skip") }
    }

    enum PhotoViewer {
        static var close: String { String(localized: "photoViewer.close") }
    }

    enum PlanOverview {
        static var title: String { String(localized: "planOverview.title") }
        static var body: String { String(localized: "planOverview.body") }
        static var close: String { String(localized: "planOverview.close") }
        static var onboardingLink: String { String(localized: "planOverview.onboardingLink") }
        static func weekLabel(_ n: Int) -> String {
            String(localized: "planOverview.weekLabel", defaultValue: "Week \(n)")
        }
        static func dayLabel(_ n: Int) -> String {
            String(localized: "planOverview.dayLabel", defaultValue: "Day \(n)")
        }
        static func minutes(_ n: Int) -> String {
            String(localized: "planOverview.minutes", defaultValue: "\(n) min")
        }
        static var statusDone: String { String(localized: "planOverview.statusDone") }
        static var statusNext: String { String(localized: "planOverview.statusNext") }
    }

    enum PlanSetup {
        static var save: String { String(localized: "planSetup.save") }
        static var cancel: String { String(localized: "planSetup.cancel") }
        static var continueTitle: String { String(localized: "planSetup.continueTitle") }
        static func coord(week: Int, day: Int) -> String {
            String(localized: "planSetup.coord", defaultValue: "Week \(week) · Day \(day)")
        }
        static var pickTitle: String { String(localized: "planSetup.pickTitle") }
        static func dayLabel(_ n: Int) -> String {
            String(localized: "planSetup.dayLabel", defaultValue: "Day \(n)")
        }
        static var startDateTitle: String { String(localized: "planSetup.startDateTitle") }
        static var startDateBody: String { String(localized: "planSetup.startDateBody") }
        static var freeDateTitle: String { String(localized: "planSetup.freeDateTitle") }
        static var freeDateBody: String { String(localized: "planSetup.freeDateBody") }
        static var freeDateToggle: String { String(localized: "planSetup.freeDateToggle") }
    }

    enum Calendar {
        static func dayTitle(week: Int, day: Int) -> String {
            String(localized: "calendar.dayTitle", defaultValue: "Week \(week) · Day \(day)")
        }
        static var statTime: String { String(localized: "calendar.statTime") }
        static var statFelt: String { String(localized: "calendar.statFelt") }
        static func feltValue(_ rating: Int) -> String {
            String(localized: "calendar.feltValue", defaultValue: "\(rating) / 10")
        }
        static var statStatus: String { String(localized: "calendar.statStatus") }
        static var statusDone: String { String(localized: "calendar.statusDone") }
        static var pillToday: String { String(localized: "calendar.pillToday") }
        static var pillScheduled: String { String(localized: "calendar.pillScheduled") }
        static var nothingScheduled: String { String(localized: "calendar.nothingScheduled") }
        static var photoUnavailable: String { String(localized: "calendar.photoUnavailable") }
    }

    enum Settings {
        static var title: String { String(localized: "settings.title") }
        static var appearance: String { String(localized: "settings.appearance") }
        static var plan: String { String(localized: "settings.plan") }
        static var trainingPlanRow: String { String(localized: "settings.trainingPlanRow") }
        static var trainingPlanValue: String { String(localized: "settings.trainingPlanValue") }
        static var scheduleRow: String { String(localized: "settings.scheduleRow") }
        static var scheduleValueNotSet: String { String(localized: "settings.scheduleValueNotSet") }
        static var scheduleNotUsed: String { String(localized: "settings.scheduleNotUsed") }
        static func scheduleStartsWeekday(_ weekday: String) -> String {
            String(localized: "settings.scheduleStartsWeekday", defaultValue: "Starts \(weekday)")
        }

        static func modeName(_ mode: TrainingMode) -> String {
            switch mode {
            case .threeDay: return String(localized: "settings.modeThreeDay")
            case .free: return String(localized: "settings.modeFree")
            }
        }
        static var switchModeTitle: String { String(localized: "settings.switchModeTitle") }
        static var switchModeBody: String { String(localized: "settings.switchModeBody") }
        static var reminders: String { String(localized: "settings.reminders") }
        static var remindersToggle: String { String(localized: "settings.reminders.toggle") }
        static var remindersCaption: String { String(localized: "settings.reminders.caption") }
        static var remindersDeniedTitle: String { String(localized: "settings.reminders.deniedTitle") }
        static var remindersDeniedBody: String { String(localized: "settings.reminders.deniedBody") }
        static var remindersDeniedOpenSettings: String { String(localized: "settings.reminders.deniedOpenSettings") }
        static var remindersDeniedCancel: String { String(localized: "settings.reminders.deniedCancel") }
        static var audio: String { String(localized: "settings.audio") }
        static var dimOtherAudio: String { String(localized: "settings.dimOtherAudio") }
        static var dimOtherAudioCaption: String { String(localized: "settings.dimOtherAudioCaption") }
        static var resetButton: String { String(localized: "settings.reset.button") }
        static var resetFooterCaption: String { String(localized: "settings.reset.footerCaption") }
        static var resetAlertTitle: String { String(localized: "settings.reset.alertTitle") }
        static var resetAlertBody: String { String(localized: "settings.reset.alertBody") }
        static var resetAlertConfirm: String { String(localized: "settings.reset.alertConfirm") }
        static var resetAlertCancel: String { String(localized: "settings.reset.alertCancel") }
    }

    enum Reminders {
        static func notificationTitle(week: Int, day: Int) -> String {
            String(localized: "reminders.notification.title",
                   defaultValue: "Run day — Week \(week) · Day \(day)")
        }
        static func notificationBody(minutes: Int, summary: String) -> String {
            String(localized: "reminders.notification.body",
                   defaultValue: "\(minutes) min · \(summary)")
        }
    }
}

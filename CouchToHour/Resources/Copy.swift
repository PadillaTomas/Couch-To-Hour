import Foundation

/// Every user-facing string in the app, loaded once from `Copy.<lang>.json` in
/// the bundle so product copy can be revised without touching Swift.
///
/// - Keys are dotted paths into the JSON tree.
/// - `{placeholder}` tokens in a value are filled from `args`.
/// - A missing key returns the key itself and trips an assertion in DEBUG, so a
///   typo is loud in development but never a crash in the field.
///
/// Localization is not wired up yet — CTH-10 is a copy pass, English only. The
/// loader already prefers `Copy.<languageCode>.json` and falls back to
/// `Copy.en.json`, so adding a language later is just adding a file. See
/// `LOCALIZATION.md` for how this would move to a String Catalog if/when we do
/// real i18n.
enum Copy {

    // MARK: Lookup

    static func string(_ key: String, _ args: [String: CustomStringConvertible] = [:]) -> String {
        guard let raw = Store.shared.strings[key] else {
            assertionFailure("Missing copy key: \(key)")
            return key
        }
        guard !args.isEmpty else { return raw }
        return args.reduce(raw) { text, pair in
            text.replacingOccurrences(of: "{\(pair.key)}", with: pair.value.description)
        }
    }

    static func list(_ key: String) -> [String] {
        guard let array = Store.shared.arrays[key] else {
            assertionFailure("Missing copy list: \(key)")
            return []
        }
        return array
    }

    // MARK: Loading

    private struct Store {
        let strings: [String: String]
        let arrays: [String: [String]]

        static let shared = Store()

        init() {
            var strings: [String: String] = [:]
            var arrays: [String: [String]] = [:]
            if let data = Self.bundledData(),
               let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                Self.flatten(root, prefix: "", strings: &strings, arrays: &arrays)
            } else {
                assertionFailure("Copy JSON missing or malformed in bundle")
            }
            self.strings = strings
            self.arrays = arrays
        }

        private static func bundledData() -> Data? {
            let lang = Locale.current.language.languageCode?.identifier ?? "en"
            for name in ["Copy.\(lang)", "Copy.en"] {
                if let url = Bundle.main.url(forResource: name, withExtension: "json"),
                   let data = try? Data(contentsOf: url) {
                    return data
                }
            }
            return nil
        }

        private static func flatten(_ node: [String: Any], prefix: String,
                                    strings: inout [String: String],
                                    arrays: inout [String: [String]]) {
            for (key, value) in node where !key.hasPrefix("_") {
                let path = prefix.isEmpty ? key : "\(prefix).\(key)"
                switch value {
                case let text as String:
                    strings[path] = text
                case let nested as [String: Any]:
                    flatten(nested, prefix: path, strings: &strings, arrays: &arrays)
                case let items as [Any]:
                    arrays[path] = items.compactMap { $0 as? String }
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Typed accessors
//
// One property per string so call sites stay compile-checked and greppable.
// The words themselves live in Copy.en.json.

extension Copy {

    enum Tabs {
        static var today: String { string("tabs.today") }
        static var calendar: String { string("tabs.calendar") }
        static var settings: String { string("tabs.settings") }
    }

    enum Onboarding {
        static var modeEyebrow: String { string("onboarding.mode.eyebrow") }
        static var modeTitle: String { string("onboarding.mode.title") }
        static var modeBody: String { string("onboarding.mode.body") }
        static var threeDayTitle: String { string("onboarding.mode.threeDayTitle") }
        static var threeDayBody: String { string("onboarding.mode.threeDayBody") }
        static var freeTitle: String { string("onboarding.mode.freeTitle") }
        static var freeBody: String { string("onboarding.mode.freeBody") }

        static var startingWeekTitle: String { string("onboarding.startingWeek.title") }
        static var startingWeekBody: String { string("onboarding.startingWeek.body") }
        static func weekLabel(_ n: Int) -> String { string("onboarding.startingWeek.weekLabel", ["n": n]) }
        static var weekBlurbs: [String] { list("onboarding.startingWeek.blurbs") }

        static var startWeekdayTitle: String { string("onboarding.startWeekday.title") }
        static var startWeekdayBody: String { string("onboarding.startWeekday.body") }

        static var philosophyTitle: String { string("onboarding.philosophy.title") }
        static var philosophyBody1: String { string("onboarding.philosophy.body1") }
        static var philosophyBody2: String { string("onboarding.philosophy.body2") }

        static var footerContinue: String { string("onboarding.footer.continue") }
        static var footerStart: String { string("onboarding.footer.start") }
        static var footerBack: String { string("onboarding.footer.back") }
    }

    enum Today {
        static var eyebrow: String { string("today.eyebrow") }
        static var makeupEyebrow: String { string("today.makeupEyebrow") }
        static func dayTitle(week: Int, day: Int) -> String {
            string("today.dayTitle", ["week": week, "day": day])
        }
        static func daySubtitle(minutes: Int, summary: String) -> String {
            string("today.daySubtitle", ["minutes": minutes, "summary": summary])
        }
        static var settingUp: String { string("today.settingUp") }
        static var restDayTitle: String { string("today.restDay.title") }
        static var restDayBody: String { string("today.restDay.body") }
        static var planCompleteTitle: String { string("today.planComplete.title") }
        static var planCompleteBody: String { string("today.planComplete.body") }

        static var actionStart: String { string("today.actions.start") }
        static var actionResume: String { string("today.actions.resume") }
        static var actionStartOver: String { string("today.actions.startOver") }
        static var actionMarkDone: String { string("today.actions.markDone") }

        static var missedEyebrow: String { string("today.missed.eyebrow") }
        static func missedTitle(week: Int, day: Int) -> String {
            string("today.missed.title", ["week": week, "day": day])
        }
        static var missedBody: String { string("today.missed.body") }
        static var missedDoTitle: String { string("today.missed.doMissedTitle") }
        static func missedDoBody(week: Int, day: Int) -> String {
            string("today.missed.doMissedBody", ["week": week, "day": day])
        }
        static var missedContinueTodayTitle: String { string("today.missed.continueTodayTitle") }
    }

    enum Timer {
        static var runCaption: String { string("timer.runCaption") }
        static var walkCaption: String { string("timer.walkCaption") }
        static var pause: String { string("timer.pause") }
        static var resume: String { string("timer.resume") }
        static var endSession: String { string("timer.endSession") }
        static var endConfirmTitle: String { string("timer.endConfirm.title") }
        static var endConfirmConfirm: String { string("timer.endConfirm.confirm") }
        static var endConfirmCancel: String { string("timer.endConfirm.cancel") }
        static var endConfirmBody: String { string("timer.endConfirm.body") }
    }

    enum PostWorkout {
        static var eyebrow: String { string("postWorkout.eyebrow") }
        static var title: String { string("postWorkout.title") }
        static var body: String { string("postWorkout.body") }
        static var easyLabel: String { string("postWorkout.easyLabel") }
        static var hardLabel: String { string("postWorkout.hardLabel") }
        static var save: String { string("postWorkout.save") }
        static var skip: String { string("postWorkout.skip") }
    }

    enum Calendar {
        static func dayTitle(week: Int, day: Int) -> String {
            string("calendar.dayTitle", ["week": week, "day": day])
        }
        static var statTime: String { string("calendar.statTime") }
        static var statFelt: String { string("calendar.statFelt") }
        static func feltValue(_ rating: Int) -> String { string("calendar.feltValue", ["rating": rating]) }
        static var statStatus: String { string("calendar.statStatus") }
        static var statusDone: String { string("calendar.statusDone") }
        static var pillToday: String { string("calendar.pillToday") }
        static var pillScheduled: String { string("calendar.pillScheduled") }
        static var nothingScheduled: String { string("calendar.nothingScheduled") }
    }

    enum Settings {
        static var title: String { string("settings.title") }
        static var appearance: String { string("settings.appearance") }
        static var plan: String { string("settings.plan") }
        static var trainingPlanRow: String { string("settings.trainingPlanRow") }
        static var trainingPlanValue: String { string("settings.trainingPlanValue") }
        static var scheduleRow: String { string("settings.scheduleRow") }
        static var scheduleValueNotSet: String { string("settings.scheduleValueNotSet") }
        static var audio: String { string("settings.audio") }
        static var dimOtherAudio: String { string("settings.dimOtherAudio") }
        static var dimOtherAudioCaption: String { string("settings.dimOtherAudioCaption") }
        static var resetButton: String { string("settings.reset.button") }
        static var resetFooterCaption: String { string("settings.reset.footerCaption") }
        static var resetAlertTitle: String { string("settings.reset.alertTitle") }
        static var resetAlertBody: String { string("settings.reset.alertBody") }
        static var resetAlertConfirm: String { string("settings.reset.alertConfirm") }
        static var resetAlertCancel: String { string("settings.reset.alertCancel") }
    }
}

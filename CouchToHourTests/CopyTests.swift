import XCTest
@testable import CouchToHour

/// Guards the copy layer: every typed accessor must resolve to a real string from
/// `Localizable.xcstrings`. A missing key surfaces as the raw dotted key — e.g.
/// `"timer.endSession"` — so `resolves(_:)` rejects that shape.
final class CopyTests: XCTestCase {

    /// True unless the string looks like an unresolved key (`word.word[.word…]`
    /// with no spaces).
    private func resolves(_ s: String) -> Bool {
        !s.isEmpty && !(s.range(of: #"^\w+(\.\w+)+$"#, options: .regularExpression) != nil)
    }

    func testEveryStringResolves() {
        let values: [String] = [
            Copy.Tabs.today, Copy.Tabs.calendar, Copy.Tabs.settings,

            Copy.Onboarding.modeEyebrow, Copy.Onboarding.modeTitle, Copy.Onboarding.modeBody,
            Copy.Onboarding.threeDayTitle, Copy.Onboarding.threeDayBody,
            Copy.Onboarding.freeTitle, Copy.Onboarding.freeBody,
            Copy.Onboarding.startingWeekTitle, Copy.Onboarding.startingWeekBody,
            Copy.Onboarding.startWeekdayTitle, Copy.Onboarding.startWeekdayBody,
            Copy.Onboarding.philosophyTitle, Copy.Onboarding.philosophyBody1, Copy.Onboarding.philosophyBody2,
            Copy.Onboarding.footerContinue, Copy.Onboarding.footerStart, Copy.Onboarding.footerBack,

            Copy.Today.eyebrow, Copy.Today.makeupEyebrow, Copy.Today.settingUp,
            Copy.Today.restDayTitle, Copy.Today.restDayBody,
            Copy.Today.planCompleteTitle, Copy.Today.planCompleteBody,
            Copy.Today.actionStart, Copy.Today.actionResume, Copy.Today.actionStartOver, Copy.Today.actionMarkDone,
            Copy.Today.missedEyebrow, Copy.Today.missedBody,
            Copy.Today.missedDoTitle, Copy.Today.missedContinueTodayTitle,

            Copy.Timer.runCaption, Copy.Timer.walkCaption, Copy.Timer.pause, Copy.Timer.resume,
            Copy.Timer.endSession, Copy.Timer.endConfirmTitle, Copy.Timer.endConfirmConfirm,
            Copy.Timer.endConfirmCancel, Copy.Timer.endConfirmBody,

            Copy.PostWorkout.eyebrow, Copy.PostWorkout.title, Copy.PostWorkout.body,
            Copy.PostWorkout.easyLabel, Copy.PostWorkout.hardLabel, Copy.PostWorkout.save, Copy.PostWorkout.skip,

            Copy.Calendar.statTime, Copy.Calendar.statFelt, Copy.Calendar.statStatus, Copy.Calendar.statusDone,
            Copy.Calendar.pillToday, Copy.Calendar.pillScheduled, Copy.Calendar.nothingScheduled,

            Copy.Settings.title, Copy.Settings.appearance, Copy.Settings.plan,
            Copy.Settings.trainingPlanRow, Copy.Settings.trainingPlanValue,
            Copy.Settings.scheduleRow, Copy.Settings.scheduleValueNotSet,
            Copy.Settings.audio, Copy.Settings.dimOtherAudio, Copy.Settings.dimOtherAudioCaption,
            Copy.Settings.resetButton, Copy.Settings.resetFooterCaption,
            Copy.Settings.resetAlertTitle, Copy.Settings.resetAlertBody,
            Copy.Settings.resetAlertConfirm, Copy.Settings.resetAlertCancel,
        ]
        for value in values {
            XCTAssertTrue(resolves(value), "Unresolved key surfaced as copy: \(value)")
        }
        // Spot-check a couple against the catalog's English.
        XCTAssertEqual(Copy.Timer.endSession, "End session")
        XCTAssertEqual(Copy.Settings.resetAlertTitle, "Reset the app?")
    }

    func testInterpolatedStringsResolve() {
        XCTAssertEqual(Copy.Onboarding.weekLabel(3), "Week 3")
        XCTAssertEqual(Copy.Today.dayTitle(week: 2, day: 1), "Week 2 · Day 1")
        XCTAssertEqual(Copy.Today.missedTitle(week: 4, day: 3), "You missed Week 4 · Day 3")
        XCTAssertEqual(Copy.Calendar.feltValue(7), "7 / 10")
        XCTAssertEqual(Copy.Today.daySubtitle(minutes: 22, summary: "5 run intervals"), "22 min · 5 run intervals")
    }

    func testWeekBlurbsCoverAllSixWeeks() {
        let blurbs = Copy.Onboarding.weekBlurbs
        XCTAssertEqual(blurbs.count, 6)
        XCTAssertFalse(blurbs.contains { $0.isEmpty || $0.contains("blurb") })
    }
}

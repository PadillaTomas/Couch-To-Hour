import XCTest
@testable import CouchToHour

/// Guards the copy layer: every typed accessor must resolve to a real string
/// from `Copy.en.json`. A missing key trips an assertion inside `Copy.string`,
/// so simply touching each accessor is most of the test; the explicit checks
/// below catch the subtler "key resolved but to something empty / wrong shape".
final class CopyTests: XCTestCase {

    func testEveryStringResolvesToNonEmpty() {
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
            XCTAssertFalse(value.isEmpty)
            XCTAssertFalse(value.contains("{"), "Unfilled placeholder in: \(value)")
        }
    }

    func testPlaceholdersAreFilled() {
        XCTAssertEqual(Copy.Onboarding.weekLabel(3), "Week 3")
        XCTAssertEqual(Copy.Today.dayTitle(week: 2, day: 1), "Week 2 · Day 1")
        XCTAssertEqual(Copy.Today.missedTitle(week: 4, day: 3), "You missed Week 4 · Day 3")
        XCTAssertEqual(Copy.Calendar.feltValue(7), "7 / 10")
        XCTAssertEqual(Copy.Today.daySubtitle(minutes: 22, summary: "x"), "22 min · x")
    }

    func testWeekBlurbsCoverAllSixWeeks() {
        XCTAssertEqual(Copy.Onboarding.weekBlurbs.count, 6)
        XCTAssertFalse(Copy.Onboarding.weekBlurbs.contains { $0.isEmpty })
    }
}

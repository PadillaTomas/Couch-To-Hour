import SwiftData
import XCTest
@testable import CouchToHour

@MainActor
final class UserSettingsTests: XCTestCase {

    func testModeRoundTripsThroughItsRawValue() {
        let settings = UserSettings(mode: .free)
        XCTAssertEqual(settings.mode, .free)

        settings.mode = .threeDay
        XCTAssertEqual(settings.mode, .threeDay)
        XCTAssertEqual(settings.modeRaw, TrainingMode.threeDay.rawValue)
    }

    func testUnknownRawValueFallsBackToThreeDay() {
        let settings = UserSettings()
        settings.modeRaw = "not-a-real-mode"
        XCTAssertEqual(settings.mode, .threeDay)
    }

    /// Covers both persistence across a relaunch *and* `current(in:)`
    /// idempotency: the second launch calls `current(in:)` on a store that
    /// already has a row, and the `fetchCount == 1` assertion fails if it
    /// created a duplicate instead of returning the existing one.
    func testSettingsSurviveAStoreReload() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cth-\(UUID().uuidString).store")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        let config = ModelConfiguration(url: url)

        let firstLaunch = try ModelContainer(for: CouchToHourSchema.schema, configurations: config)
        UserSettings.current(in: firstLaunch.mainContext).mode = .free
        try firstLaunch.mainContext.save()

        let relaunch = try ModelContainer(for: CouchToHourSchema.schema, configurations: config)
        let reloaded = UserSettings.current(in: relaunch.mainContext)
        XCTAssertEqual(reloaded.mode, .free)
        XCTAssertEqual(try relaunch.mainContext.fetchCount(FetchDescriptor<UserSettings>()), 1)
    }
}

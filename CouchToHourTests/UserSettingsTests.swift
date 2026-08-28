import SwiftData
import XCTest
import UIWorkouts
@testable import CouchToHour

@MainActor
final class UserSettingsTests: XCTestCase {

    func testThemeModeRoundTripsThroughItsRawValue() {
        let settings = UserSettings(themeMode: .dark)
        XCTAssertEqual(settings.themeMode, .dark)

        settings.themeMode = .light
        XCTAssertEqual(settings.themeMode, .light)
        XCTAssertEqual(settings.themeModeRaw, WKThemeMode.light.rawValue)
    }

    func testUnknownRawValueFallsBackToSystem() {
        let settings = UserSettings()
        settings.themeModeRaw = "not-a-real-mode"
        XCTAssertEqual(settings.themeMode, .system)
    }

    /// Covers both persistence across a relaunch *and* `current(in:)`
    /// idempotency: the second launch calls `current(in:)` on a store that
    /// already has a row, and the `fetchCount == 1` assertion fails if it
    /// created a duplicate instead of returning the existing one.
    func testThemeChoiceSurvivesAStoreReload() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cth-\(UUID().uuidString).store")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        let config = ModelConfiguration(url: url)

        let firstLaunch = try ModelContainer(for: CouchToHourSchema.schema, configurations: config)
        UserSettings.current(in: firstLaunch.mainContext).themeMode = .dark
        try firstLaunch.mainContext.save()

        let relaunch = try ModelContainer(for: CouchToHourSchema.schema, configurations: config)
        let reloaded = UserSettings.current(in: relaunch.mainContext)
        XCTAssertEqual(reloaded.themeMode, .dark)
        XCTAssertEqual(try relaunch.mainContext.fetchCount(FetchDescriptor<UserSettings>()), 1)
    }
}

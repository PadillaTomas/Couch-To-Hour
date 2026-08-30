import SwiftData
import UserNotifications
import XCTest
@testable import CouchToHour

@MainActor
final class SessionReminderSyncTests: XCTestCase {

    /// In-memory stand-in for `UNUserNotificationCenter`.
    private final class FakeCenter: UserNotificationScheduling {
        var status: UNAuthorizationStatus
        private(set) var pending: [String: UNNotificationRequest] = [:]

        init(status: UNAuthorizationStatus = .authorized, preloaded: [String] = []) {
            self.status = status
            for id in preloaded { pending[id] = Self.request(id) }
        }
        static func request(_ id: String) -> UNNotificationRequest {
            UNNotificationRequest(identifier: id, content: UNMutableNotificationContent(),
                                  trigger: nil)
        }
        func alertAuthorizationStatus() async -> UNAuthorizationStatus { status }
        func requestAlertAuthorization() async -> Bool { status == .authorized }
        func pendingSessionReminderIDs() async -> [String] {
            pending.keys.filter { $0.hasPrefix(SessionReminder.identifierPrefix) }
        }
        func removeSessionReminders(ids: [String]) { ids.forEach { pending[$0] = nil } }
        func scheduleSessionReminder(_ request: UNNotificationRequest) async {
            pending[request.identifier] = request
        }
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func scheduledPlan(in context: ModelContext) throws -> WorkoutPlan {
        try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first)
    }
    private func settings(_ context: ModelContext,
                          mode: TrainingMode = .threeDay,
                          enabled: Bool = true) -> UserSettings {
        let s = UserSettings.current(in: context)
        s.mode = mode
        s.notificationsEnabled = enabled
        s.startingWeek = 1
        s.startingDay = 1
        s.startDate = date(2026, 1, 5)
        return s
    }

    func testSchedulesEveryUpcomingSessionWhenOnAndAuthorized() async throws {
        let context = try seededContainer().mainContext
        let plan = try scheduledPlan(in: context)
        let center = FakeCenter(status: .authorized)

        await SessionReminderSync.reconcile(
            plan: plan, settings: settings(context), completions: [],
            center: center, now: date(2026, 1, 4), calendar: calendar)

        XCTAssertEqual(center.pending.count, 18)
        XCTAssertTrue(center.pending.keys.allSatisfy { $0.hasPrefix(SessionReminder.identifierPrefix) })
        let w1d1 = try XCTUnwrap(center.pending["cth.session.W1D1"])
        XCTAssertEqual(w1d1.content.title, Copy.Reminders.notificationTitle(week: 1, day: 1))
        XCTAssertTrue(w1d1.trigger is UNCalendarNotificationTrigger)
    }

    func testToggleOffClearsEverythingAndSchedulesNothing() async throws {
        let context = try seededContainer().mainContext
        let plan = try scheduledPlan(in: context)
        let center = FakeCenter(status: .authorized,
                                preloaded: ["cth.session.W1D1", "cth.session.W1D2"])

        await SessionReminderSync.reconcile(
            plan: plan, settings: settings(context, enabled: false), completions: [],
            center: center, now: date(2026, 1, 4), calendar: calendar)

        XCTAssertTrue(center.pending.isEmpty)
    }

    func testFreeModeClearsEverything() async throws {
        let context = try seededContainer().mainContext
        let plan = try scheduledPlan(in: context)
        let center = FakeCenter(status: .authorized, preloaded: ["cth.session.W2D3"])

        await SessionReminderSync.reconcile(
            plan: plan, settings: settings(context, mode: .free), completions: [],
            center: center, now: date(2026, 1, 4), calendar: calendar)

        XCTAssertTrue(center.pending.isEmpty)
    }

    func testUnauthorizedSchedulesNothing() async throws {
        let context = try seededContainer().mainContext
        let plan = try scheduledPlan(in: context)
        let center = FakeCenter(status: .denied)

        await SessionReminderSync.reconcile(
            plan: plan, settings: settings(context), completions: [],
            center: center, now: date(2026, 1, 4), calendar: calendar)

        XCTAssertTrue(center.pending.isEmpty)
    }

    func testStaleRemindersAreReplacedNotStacked() async throws {
        let context = try seededContainer().mainContext
        let plan = try scheduledPlan(in: context)
        // A reminder for a session that is now in the past + a bogus one.
        let center = FakeCenter(status: .authorized,
                                preloaded: ["cth.session.W1D1", "cth.session.W99D9"])

        await SessionReminderSync.reconcile(
            plan: plan, settings: settings(context), completions: [],
            center: center, now: date(2026, 1, 20), calendar: calendar)

        XCTAssertFalse(center.pending.keys.contains("cth.session.W1D1"))
        XCTAssertFalse(center.pending.keys.contains("cth.session.W99D9"))
        XCTAssertTrue(center.pending.keys.allSatisfy { $0.hasPrefix(SessionReminder.identifierPrefix) })
        XCTAssertFalse(center.pending.isEmpty)   // later weeks still scheduled
    }
}

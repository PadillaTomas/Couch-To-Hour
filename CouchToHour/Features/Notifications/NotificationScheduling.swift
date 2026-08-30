import Foundation
import UserNotifications

/// The slice of `UNUserNotificationCenter` the reminder sync needs, behind a
/// protocol so the sync logic is testable — the real center can't be built
/// outside an app bundle.
protocol UserNotificationScheduling {
    func alertAuthorizationStatus() async -> UNAuthorizationStatus
    /// Prompts on the first call; returns whether alerts are now permitted.
    func requestAlertAuthorization() async -> Bool
    /// Pending request ids that belong to session reminders (see
    /// ``SessionReminder/identifierPrefix``).
    func pendingSessionReminderIDs() async -> [String]
    func removeSessionReminders(ids: [String])
    func scheduleSessionReminder(_ request: UNNotificationRequest) async
}

extension UNUserNotificationCenter: UserNotificationScheduling {
    func alertAuthorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }

    func requestAlertAuthorization() async -> Bool {
        (try? await requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func pendingSessionReminderIDs() async -> [String] {
        await pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(SessionReminder.identifierPrefix) }
    }

    func removeSessionReminders(ids: [String]) {
        removePendingNotificationRequests(withIdentifiers: ids)
    }

    func scheduleSessionReminder(_ request: UNNotificationRequest) async {
        try? await add(request)
    }
}

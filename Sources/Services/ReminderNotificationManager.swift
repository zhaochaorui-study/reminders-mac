import Foundation
import UserNotifications

final class ReminderNotificationManager: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private enum Constants {
        static let systemNotificationsEnabled = false
    }

    static let shared = ReminderNotificationManager()

    private let center = UNUserNotificationCenter.current()
    private static let identifierPrefix = "reminders-mac."
    private var hasRequestedAuthorization = false

    private override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        guard Constants.systemNotificationsEnabled else {
            removeAllManagedNotifications()
            return
        }

        guard hasRequestedAuthorization == false else {
            return
        }

        hasRequestedAuthorization = true
        center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func syncNotifications(for items: [ReminderItem], now: Date = Date()) {
        guard Constants.systemNotificationsEnabled else {
            removeAllManagedNotifications()
            return
        }

        let activeItems = items.filter { !$0.isCompleted && $0.scheduledAt > now }
        let activeIdentifiers = Set(activeItems.map { identifier(for: $0.id) })

        center.getPendingNotificationRequests { [center] requests in
            let staleIdentifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.identifierPrefix) && !activeIdentifiers.contains($0) }

            if staleIdentifiers.isEmpty == false {
                center.removePendingNotificationRequests(withIdentifiers: staleIdentifiers)
            }
        }

        for item in activeItems {
            scheduleNotification(for: item)
        }
    }

    func cancelNotification(for reminderID: UUID) {
        let identifier = identifier(for: reminderID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    private func scheduleNotification(for item: ReminderItem) {
        let content = UNMutableNotificationContent()
        content.title = "提醒"
        content.body = item.title
        content.sound = .default

        let components = Calendar.autoupdatingCurrent.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: item.scheduledAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(for: item.id),
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    private func removeAllManagedNotifications() {
        center.getPendingNotificationRequests { [center] requests in
            let pendingIdentifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.identifierPrefix) }

            if pendingIdentifiers.isEmpty == false {
                center.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)
            }
        }

        center.getDeliveredNotifications { [center] notifications in
            let deliveredIdentifiers = notifications
                .map(\.request.identifier)
                .filter { $0.hasPrefix(Self.identifierPrefix) }

            if deliveredIdentifiers.isEmpty == false {
                center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
            }
        }
    }

    private func identifier(for reminderID: UUID) -> String {
        "\(Self.identifierPrefix)\(reminderID.uuidString)"
    }
}

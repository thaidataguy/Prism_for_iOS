import Combine
import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published var reminderHour: Int
    @Published var reminderMinute: Int

    private let center: UNUserNotificationCenter
    private let userDefaults: UserDefaults
    private let hourKey = "orbit.notifications.hour"
    private let minuteKey = "orbit.notifications.minute"
    private let requestIdentifier = "orbit.daily.checkin"

    init(
        center: UNUserNotificationCenter = .current(),
        userDefaults: UserDefaults = .standard
    ) {
        self.center = center
        self.userDefaults = userDefaults
        self.reminderHour = userDefaults.object(forKey: hourKey) as? Int ?? 20
        self.reminderMinute = userDefaults.object(forKey: minuteKey) as? Int ?? 0
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    func requestPermission() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted

            if granted {
                scheduleDailyReminder(hour: reminderHour, minute: reminderMinute)
            }
        } catch {
            assertionFailure("Notification permission error: \(error)")
        }
    }

    func syncScheduledReminderIfNeeded() async {
        guard isAuthorized else { return }
        scheduleDailyReminder(hour: reminderHour, minute: reminderMinute)
    }

    func scheduleDailyReminder(hour: Int, minute: Int) {
        reminderHour = hour
        reminderMinute = minute

        userDefaults.set(hour, forKey: hourKey)
        userDefaults.set(minute, forKey: minuteKey)

        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Prism check-in"
        content.body = "How did career, health, and social feel today?"
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                assertionFailure("Scheduling error: \(error)")
            }
        }
    }
}

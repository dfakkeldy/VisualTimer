import Foundation
import UserNotifications

/// Schedules one local notification for the moment the running countdown
/// ends, so time's up is heard even when Turn Timer isn't on screen. Opt-in
/// from Settings; pausing, skipping, ending or resetting removes it.
enum TimerAlertScheduler {
    static let enabledKey = "timerAlertsEnabled"
    private static let requestID = "turntimer.timer-end"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Whether iOS currently allows Turn Timer's notifications. Read on
    /// appear, so a switch never shows a state that isn't true.
    static func isAuthorized() async -> Bool? {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        case .notDetermined: return nil
        @unknown default: return nil
        }
    }

    /// Asks for permission. Returns whether alerts can now be shown.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        return granted
    }

    /// Replaces any pending alert with one for `finishDate`, or removes it.
    static func update(finishDate: Date?, title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        guard isEnabled, let finishDate else { return }
        let interval = finishDate.timeIntervalSinceNow
        guard interval > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: requestID, content: content, trigger: trigger))
    }
}

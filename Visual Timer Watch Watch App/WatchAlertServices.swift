import Foundation
import OSLog
import UserNotifications
import WatchKit

// MARK: - Notifications

/// Local-notification adapter for Watch timer completion.
///
/// Notifications are the only background alert path. Turn Timer does not
/// keep running, play audio or tap the wrist after watchOS suspends it, and
/// it uses no extended runtime session. Notification sound is the system
/// default; the generated Turn Timer tones play only in the app.
@MainActor
final class WatchNotificationScheduler: NSObject, WatchTimerNotificationScheduling, UNUserNotificationCenterDelegate {

    /// Returns true when the app is on screen and handled the completion
    /// itself, so the banner would duplicate the in-app alert.
    var handleForegroundPresentation: (() -> Bool)?

    /// `UNTimeIntervalNotificationTrigger` requires a positive interval.
    private static let minimumDelay: TimeInterval = 1

    private let logger = Logger(subsystem: "Dan.Visual-Timer", category: "WatchTimerAlerts")
    private var addsInFlight: Set<String> = []
    private var cancelledWhileAdding: Set<String> = []

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func currentPermission() async -> WatchNotificationPermission {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return .allowed
        case .notDetermined:
            return .notDetermined
        default:
            return .denied
        }
    }

    /// Call only from an explicit user action such as the Allow Alerts row.
    func requestPermission() async -> WatchNotificationPermission {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("Notification permission request failed.")
        }
        return await currentPermission()
    }

    // MARK: - WatchTimerNotificationScheduling

    func schedule(_ notification: WatchTimerNotification) {
        let identifier = notification.identifier
        let title = notification.title
        let body = notification.body
        let delay = max(notification.fireDate.timeIntervalSinceNow, Self.minimumDelay)
        addsInFlight.insert(identifier)

        Task {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            )
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                logger.error("Unable to schedule a Watch timer notification.")
            }
            addsInFlight.remove(identifier)
            // A pause or reset can overtake an add that was still in flight.
            if cancelledWhileAdding.remove(identifier) != nil {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            }
        }
    }

    func cancel(identifier: String) {
        if addsInFlight.contains(identifier) {
            cancelledWhileAdding.insert(identifier)
        }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// While Turn Timer is active, it reconciles immediately and plays its own
    /// alert, so the banner is suppressed. While it is frontmost but inactive
    /// (wrist down), the banner and sound are shown.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let handledInApp = await MainActor.run { [weak self] in
            self?.handleForegroundPresentation?() ?? false
        }
        return handledInApp ? [] : [.banner, .list, .sound]
    }
}

// MARK: - Device Feedback

/// Plays Watch completion feedback: a WatchKit haptic and the user's
/// selected Turn Timer sound through `SoundManager`.
@MainActor
final class WatchDeviceFeedback: WatchCompletionFeedback {

    private let soundManager: SoundManager

    init(soundManager: SoundManager) {
        self.soundManager = soundManager
    }

    func play(_ alert: WatchCompletionAlert) {
        switch alert {
        case .soundAndHaptic:
            WKInterfaceDevice.current().play(.notification)
            soundManager.playFinishSound()
        case .haptic:
            WKInterfaceDevice.current().play(.notification)
        case .none:
            break
        }
    }
}

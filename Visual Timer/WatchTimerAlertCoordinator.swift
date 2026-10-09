import Combine
import Foundation

// MARK: - Alert Types

/// How the Watch signals one countdown completion.
enum WatchCompletionAlert: Equatable {
    /// On screen at the deadline: the selected sound and a haptic.
    case soundAndHaptic
    /// On screen but noticed late, with no notification covering the
    /// deadline: a haptic only, never a late sound.
    case haptic
    /// A scheduled notification owns the alert, or the app is off screen.
    case none
}

/// Local-notification permission, reduced to what timer alerts need.
enum WatchNotificationPermission: Equatable {
    case notDetermined
    case allowed
    case denied
}

/// One completion notification for one running countdown.
struct WatchTimerNotification: Equatable {
    let identifier: String
    let fireDate: Date
    let title: String
    let body: String
}

/// Platform adapter that schedules and removes completion notifications.
@MainActor
protocol WatchTimerNotificationScheduling: AnyObject {
    /// Reports whether the system accepted the request, after its asynchronous add.
    func schedule(_ notification: WatchTimerNotification, completion: @escaping @MainActor (Bool) -> Void)
    /// Removes the request whether it is still pending or already delivered.
    func cancel(identifier: String)
}

/// Platform adapter that plays the chosen completion alert.
@MainActor
protocol WatchCompletionFeedback: AnyObject {
    func play(_ alert: WatchCompletionAlert)
}

// MARK: - Coordinator

/// Keeps one timer's completion alerts coherent across foreground ticks,
/// background notifications and every pause, resume, reset or round change.
///
/// The coordinator observes `TimerViewModel.visualProgress`, so each running
/// countdown has exactly one notification at its exact finish date, and any
/// non-running progress cancels it. That includes successor rounds that
/// `GameViewModel` starts. It installs the timer's `onFinish` so the alert
/// decision runs before `afterFinish` can start a successor round.
@MainActor
final class WatchTimerAlertCoordinator {

    /// A completion noticed within this window of its deadline counts as on time.
    static let onTimeTolerance: TimeInterval = 2

    private(set) var permission: WatchNotificationPermission
    private(set) var isAppActive = true
    /// The running countdown's finish date, or nil while idle or paused.
    private(set) var deadline: Date?
    /// The requested notification for `deadline`; an unresolved add can still fail.
    private(set) var pendingNotification: WatchTimerNotification?

    private let timer: TimerViewModel
    private let scheduler: WatchTimerNotificationScheduling
    private let feedback: WatchCompletionFeedback
    private let identifierPrefix: String
    private let now: () -> Date
    private let notificationText: () -> (title: String, body: String)
    /// A completion passed off screen with no notification to report it.
    private var missedAlertPending = false
    private var deadlinePassedWhileInactive = false
    private var notificationWasPresented = false
    private var issuedNotificationCount: UInt64 = 0
    private var addsInFlight: Set<String> = []
    private var completedAddsAwaitingResult: Set<String> = []
    /// Retained only until system presentation/delivery is observed.
    private var systemOwnedNotifications: Set<String> = []
    private var progressSubscription: AnyCancellable?

    init(
        timer: TimerViewModel,
        scheduler: WatchTimerNotificationScheduling,
        feedback: WatchCompletionFeedback,
        identifierPrefix: String,
        permission: WatchNotificationPermission = .notDetermined,
        now: @escaping () -> Date = Date.init,
        notificationText: @escaping () -> (title: String, body: String),
        afterFinish: (() -> Void)? = nil
    ) {
        self.timer = timer
        self.scheduler = scheduler
        self.feedback = feedback
        self.identifierPrefix = "\(identifierPrefix).\(UUID().uuidString)"
        self.permission = permission
        self.now = now
        self.notificationText = notificationText

        timer.onFinish = { [weak self] in
            self?.timerDidFinish()
            afterFinish?()
        }
        progressSubscription = timer.$visualProgress.sink { [weak self] progress in
            self?.track(progress)
        }
    }

    // MARK: - Inputs

    func updatePermission(_ permission: WatchNotificationPermission) {
        self.permission = permission
        if permission == .allowed {
            scheduleNotificationIfAllowed()
        } else {
            cancelPendingNotification()
        }
    }

    /// Records scene activity. Becoming active reconciles the countdown
    /// against `date` and reports a completion missed while off screen once.
    func sceneDidChange(isActive: Bool, at date: Date = Date()) {
        if isActive, !isAppActive, let deadline, date >= deadline {
            deadlinePassedWhileInactive = true
        }
        isAppActive = isActive
        guard isActive else { return }
        reconcile(at: date)
        if missedAlertPending {
            missedAlertPending = false
            feedback.play(.haptic)
        }
    }

    /// Reconciles the countdown with the clock, completing it at most once.
    func reconcile(at date: Date = Date()) {
        timer.refreshCountdown(at: date)
    }

    /// Nil means another coordinator/process owns this identifier. False lets
    /// the system present a background-owned alert; true suppresses a request
    /// already handled in-app or cancelled, even after its add settles.
    func handleForegroundNotification(identifier: String, at date: Date = Date()) -> Bool? {
        guard ownsIssuedIdentifier(identifier) else { return nil }
        if !isAppActive {
            if pendingNotification?.identifier == identifier {
                notificationWasPresented = true
                completedAddsAwaitingResult.remove(identifier)
                return false
            }
            if systemOwnedNotifications.remove(identifier) != nil {
                completedAddsAwaitingResult.remove(identifier)
                return false
            }
            return true
        }
        if pendingNotification?.identifier == identifier {
            reconcile(at: date)
        }
        if systemOwnedNotifications.remove(identifier) != nil {
            completedAddsAwaitingResult.remove(identifier)
            return false
        }
        return true
    }

    /// A read-only system snapshot retires background ownership without
    /// removing the user's delivered notifications or keeping UUID tombstones.
    func recordDeliveredNotifications(_ identifiers: Set<String>) {
        systemOwnedNotifications.subtract(identifiers)
        completedAddsAwaitingResult.subtract(identifiers)
        if let pendingNotification, identifiers.contains(pendingNotification.identifier) {
            notificationWasPresented = true
        }
    }

    // MARK: - Decisions

    static func completionAlert(
        isAppActive: Bool,
        lateness: TimeInterval,
        notificationScheduled: Bool,
        deadlinePassedWhileInactive: Bool = false
    ) -> WatchCompletionAlert {
        guard isAppActive else { return .none }
        if deadlinePassedWhileInactive {
            return notificationScheduled ? .none : .haptic
        }
        if lateness <= onTimeTolerance { return .soundAndHaptic }
        return notificationScheduled ? .none : .haptic
    }

    // MARK: - Private

    private func timerDidFinish() {
        let finished = pendingNotification
        let lateness = deadline.map { now().timeIntervalSince($0) } ?? 0

        let alert = Self.completionAlert(
            isAppActive: isAppActive,
            lateness: lateness,
            notificationScheduled: finished != nil,
            deadlinePassedWhileInactive: deadlinePassedWhileInactive || notificationWasPresented
        )
        if let finished {
            if alert != .none {
                scheduler.cancel(identifier: finished.identifier)
            } else if !notificationWasPresented {
                // Preserve a system-owned request even after foreground return;
                // it may still need to present after a delayed delivery.
                systemOwnedNotifications.insert(finished.identifier)
                if addsInFlight.contains(finished.identifier) {
                    completedAddsAwaitingResult.insert(finished.identifier)
                }
            }
        }
        if !isAppActive && finished == nil {
            missedAlertPending = true
        }
        pendingNotification = nil
        deadline = nil
        deadlinePassedWhileInactive = false
        notificationWasPresented = false
        if alert != .none {
            feedback.play(alert)
        }
    }

    private func track(_ progress: TimerVisualProgress) {
        let newDeadline = progress.finishDate
        guard newDeadline != deadline else { return }
        cancelPendingNotification()
        deadline = newDeadline
        deadlinePassedWhileInactive = false
        scheduleNotificationIfAllowed()
    }

    private func scheduleNotificationIfAllowed() {
        guard permission == .allowed,
              pendingNotification == nil,
              let deadline,
              deadline > now() else { return }
        let text = notificationText()
        issuedNotificationCount += 1
        let notification = WatchTimerNotification(
            identifier: "\(identifierPrefix).\(issuedNotificationCount)",
            fireDate: deadline,
            title: text.title,
            body: text.body
        )
        pendingNotification = notification
        notificationWasPresented = false
        addsInFlight.insert(notification.identifier)
        scheduler.schedule(notification) { [weak self] accepted in
            self?.notificationAddDidComplete(identifier: notification.identifier, accepted: accepted)
        }
    }

    private func notificationAddDidComplete(identifier: String, accepted: Bool) {
        addsInFlight.remove(identifier)
        if pendingNotification?.identifier == identifier {
            if !accepted, !notificationWasPresented {
                pendingNotification = nil
                scheduler.cancel(identifier: identifier)
            }
            return
        }
        guard completedAddsAwaitingResult.remove(identifier) != nil else { return }
        if !accepted {
            systemOwnedNotifications.remove(identifier)
            if isAppActive {
                feedback.play(.haptic)
            } else {
                missedAlertPending = true
            }
        }
    }

    private func ownsIssuedIdentifier(_ identifier: String) -> Bool {
        let prefix = identifierPrefix + "."
        guard identifier.hasPrefix(prefix),
              let number = UInt64(identifier.dropFirst(prefix.count)) else { return false }
        return number > 0 && number <= issuedNotificationCount
    }

    private func cancelPendingNotification() {
        guard let pendingNotification else { return }
        scheduler.cancel(identifier: pendingNotification.identifier)
        self.pendingNotification = nil
        notificationWasPresented = false
    }
}

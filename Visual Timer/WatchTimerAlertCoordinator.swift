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
    func schedule(_ notification: WatchTimerNotification)
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
    /// The notification scheduled for `deadline`, when permission allowed one.
    private(set) var pendingNotification: WatchTimerNotification?

    private let timer: TimerViewModel
    private let scheduler: WatchTimerNotificationScheduling
    private let feedback: WatchCompletionFeedback
    private let identifierPrefix: String
    private let now: () -> Date
    private let notificationText: () -> (title: String, body: String)
    /// A completion passed off screen with no notification to report it.
    private var missedAlertPending = false
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
        self.identifierPrefix = identifierPrefix
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

    // MARK: - Decisions

    static func completionAlert(
        isAppActive: Bool,
        lateness: TimeInterval,
        notificationScheduled: Bool
    ) -> WatchCompletionAlert {
        guard isAppActive else { return .none }
        if lateness <= onTimeTolerance { return .soundAndHaptic }
        return notificationScheduled ? .none : .haptic
    }

    // MARK: - Private

    private func timerDidFinish() {
        let finished = pendingNotification
        let lateness = deadline.map { now().timeIntervalSince($0) } ?? 0
        pendingNotification = nil
        deadline = nil

        let alert = Self.completionAlert(
            isAppActive: isAppActive,
            lateness: lateness,
            notificationScheduled: finished != nil
        )
        if isAppActive, let finished {
            // On screen: the app handles this completion, so remove the
            // pending or delivered notification instead of duplicating it.
            scheduler.cancel(identifier: finished.identifier)
        }
        // Off screen the request stays, so watchOS can still deliver it.
        missedAlertPending = !isAppActive && finished == nil
        if alert != .none {
            feedback.play(alert)
        }
    }

    private func track(_ progress: TimerVisualProgress) {
        let newDeadline = progress.finishDate
        guard newDeadline != deadline else { return }
        cancelPendingNotification()
        deadline = newDeadline
        scheduleNotificationIfAllowed()
    }

    private func scheduleNotificationIfAllowed() {
        guard permission == .allowed,
              pendingNotification == nil,
              let deadline,
              deadline > now() else { return }
        let text = notificationText()
        let notification = WatchTimerNotification(
            identifier: "\(identifierPrefix).\(UUID().uuidString)",
            fireDate: deadline,
            title: text.title,
            body: text.body
        )
        pendingNotification = notification
        scheduler.schedule(notification)
    }

    private func cancelPendingNotification() {
        guard let pendingNotification else { return }
        scheduler.cancel(identifier: pendingNotification.identifier)
        self.pendingNotification = nil
    }
}

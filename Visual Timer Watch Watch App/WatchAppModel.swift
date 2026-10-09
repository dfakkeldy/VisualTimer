import Combine
import Foundation

/// A template session the root list can return to.
struct WatchActiveSession: Equatable {
    let title: String
    let isComplete: Bool
}

/// Owns the Watch app's timers so countdowns survive navigation between
/// screens, and wires completion alerts, notification permission and
/// foreground reconciliation for both the quick timer and template sessions.
///
/// The quick timer and the session use separate `TimerViewModel`s because
/// `GameViewModel` reconfigures its timer for every round.
@MainActor
final class WatchAppModel: ObservableObject {

    let quickTimer: WatchQuickTimerViewModel
    let sessionTimer: TimerViewModel
    let gameViewModel: GameViewModel

    @Published private(set) var savedTemplates: [WatchTemplate] = []
    @Published private(set) var notificationPermission: WatchNotificationPermission = .notDetermined
    @Published private(set) var quickTimerState: TimerState = .notStarted
    @Published private(set) var activeSession: WatchActiveSession?

    private static let quickNotificationPrefix = "turntimer.watch.quick"
    private static let sessionNotificationPrefix = "turntimer.watch.session"

    private let soundManager: SoundManager
    private let notifications: WatchNotificationScheduler
    private let quickAlerts: WatchTimerAlertCoordinator
    private let sessionAlerts: WatchTimerAlertCoordinator

    init() {
        let soundManager = SoundManager()
        let notifications = WatchNotificationScheduler()
        let feedback = WatchDeviceFeedback(soundManager: soundManager)
        let quickTimer = TimerViewModel()
        let sessionTimer = TimerViewModel()
        let game = GameViewModel(timerViewModel: sessionTimer)

        self.soundManager = soundManager
        self.notifications = notifications
        self.quickTimer = WatchQuickTimerViewModel(timer: quickTimer)
        self.sessionTimer = sessionTimer
        self.gameViewModel = game
        self.quickAlerts = WatchTimerAlertCoordinator(
            timer: quickTimer,
            scheduler: notifications,
            feedback: feedback,
            identifierPrefix: WatchAppModel.quickNotificationPrefix,
            notificationText: {
                (Theme.Watch.Notification.quickTitle, Theme.Watch.Notification.quickBody)
            }
        )
        self.sessionAlerts = WatchTimerAlertCoordinator(
            timer: sessionTimer,
            scheduler: notifications,
            feedback: feedback,
            identifierPrefix: WatchAppModel.sessionNotificationPrefix,
            notificationText: { [weak game] in
                WatchAppModel.sessionNotificationText(for: game)
            },
            // Runs after the alert decision, so a successor round's
            // notification never replaces the finished round's alert.
            afterFinish: { [weak game] in
                game?.handleTimerFinished()
            }
        )

        notifications.handleForegroundPresentation = { [weak self] identifier in
            self?.handleForegroundNotification(identifier: identifier) ?? false
        }
        quickTimer.$state
            .removeDuplicates()
            .assign(to: &$quickTimerState)
        game.$gamePhase
            .combineLatest(game.$gameSequence)
            .map { phase, sequence -> WatchActiveSession? in
                guard phase != .idle, let sequence else { return nil }
                return WatchActiveSession(title: sequence.title, isComplete: phase == .gameOver)
            }
            .removeDuplicates()
            .assign(to: &$activeSession)
    }

    // MARK: - Scene

    func sceneDidBecomeActive(at date: Date = Date()) {
        quickAlerts.sceneDidChange(isActive: true, at: date)
        sessionAlerts.sceneDidChange(isActive: true, at: date)
        refreshSavedTemplates()
        Task {
            await refreshNotificationPermission()
            let delivered = await notifications.deliveredNotificationIdentifiers()
            quickAlerts.recordDeliveredNotifications(delivered)
            sessionAlerts.recordDeliveredNotifications(delivered)
        }
    }

    func sceneDidResignActive() {
        quickAlerts.sceneDidChange(isActive: false)
        sessionAlerts.sceneDidChange(isActive: false)
    }

    // MARK: - Notifications

    func refreshNotificationPermission() async {
        apply(await notifications.currentPermission())
    }

    /// Explicit user action from the Allow Alerts row.
    func requestNotificationPermission() {
        Task {
            apply(await notifications.requestPermission())
        }
    }

    // MARK: - Templates

    func refreshSavedTemplates() {
        savedTemplates = (try? WatchTemplateStore().read()) ?? []
    }

    // MARK: - Session

    func startSession(_ game: GameSequence) {
        gameViewModel.loadGame(game)
        gameViewModel.startGame()
    }

    /// Start, pause or resume the current round.
    func toggleSession() {
        switch sessionTimer.state {
        case .notStarted:
            if gameViewModel.gamePhase == .ready {
                gameViewModel.startGame()
            } else {
                gameViewModel.startCurrentRound()
            }
        case .paused:
            gameViewModel.recordResume()
            sessionTimer.play()
        case .running:
            sessionTimer.pause()
            // An overdue pause completes the round and starts its successor;
            // only record a pause when the timer actually paused.
            if sessionTimer.state == .paused {
                gameViewModel.recordPause()
            }
        case .finished:
            break
        }
    }

    func restartRound() {
        gameViewModel.restartCurrentTimer()
    }

    func previousRound() {
        gameViewModel.doOverToPrevious()
    }

    func skipRound() {
        gameViewModel.skipCurrentRound()
    }

    func endSession() {
        gameViewModel.endGame()
    }

    // MARK: - Private

    private func apply(_ permission: WatchNotificationPermission) {
        notificationPermission = permission
        quickAlerts.updatePermission(permission)
        sessionAlerts.updatePermission(permission)
    }

    /// A completion notification arrived while Turn Timer is frontmost.
    /// Route by identifier so a late background-owned alert can still present,
    /// while cancelled or in-app-handled requests are suppressed.
    private func handleForegroundNotification(identifier: String) -> Bool {
        let now = Date()
        if let handled = quickAlerts.handleForegroundNotification(identifier: identifier, at: now) {
            return handled
        }
        return sessionAlerts.handleForegroundNotification(identifier: identifier, at: now) ?? false
    }

    private static func sessionNotificationText(for game: GameViewModel?) -> (title: String, body: String) {
        guard let game, let round = game.currentRound else {
            return (Theme.Watch.Notification.roundFallbackTitle, game?.gameSequence?.title ?? "")
        }
        let name = round.emoji.isEmpty ? round.name : "\(round.emoji) \(round.name)"
        return (Theme.Watch.Notification.roundFinishedTitle(name), game.gameSequence?.title ?? "")
    }
}

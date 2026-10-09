import XCTest
@testable import Visual_Timer

@MainActor
final class WatchTimerQualityTests: XCTestCase {

    // MARK: - Finish date

    func testFinishDateTracksOnlyRunningProgress() {
        let start = Date(timeIntervalSince1970: 1_000)
        let idle = TimerVisualProgress(totalDuration: 60)
        XCTAssertNil(idle.finishDate)

        let running = idle.running(from: start)
        XCTAssertEqual(running.finishDate, start.addingTimeInterval(60))

        let paused = running.paused(at: start.addingTimeInterval(10.5))
        XCTAssertNil(paused.finishDate)

        let resumed = paused.running(from: start.addingTimeInterval(100))
        XCTAssertEqual(resumed.finishDate, start.addingTimeInterval(149.5))
    }

    // MARK: - Notification lifecycle

    func testPauseResumeAndResetKeepOneNotificationForTheCurrentDeadline() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .allowed)
        let start = Date(timeIntervalSince1970: 1_000)

        harness.clock.date = start
        timer.play(at: start)
        XCTAssertEqual(harness.scheduler.scheduled.map(\.fireDate), [start.addingTimeInterval(60)])

        harness.clock.date = start.addingTimeInterval(10)
        timer.pause(at: harness.clock.date)
        XCTAssertEqual(harness.scheduler.cancelled, [harness.scheduler.scheduled[0].identifier])
        XCTAssertNil(harness.coordinator.pendingNotification)

        harness.clock.date = start.addingTimeInterval(100)
        timer.play(at: harness.clock.date)
        XCTAssertEqual(harness.scheduler.scheduled.count, 2)
        XCTAssertEqual(harness.scheduler.scheduled[1].fireDate, start.addingTimeInterval(150))
        XCTAssertNotEqual(harness.scheduler.scheduled[1].identifier, harness.scheduler.scheduled[0].identifier)

        harness.clock.date = start.addingTimeInterval(110)
        timer.pause(at: harness.clock.date)
        timer.reset()

        XCTAssertEqual(harness.scheduler.scheduled.count, 2, "Reset must not schedule anything.")
        XCTAssertEqual(harness.scheduler.cancelled, harness.scheduler.scheduled.map(\.identifier))
        XCTAssertTrue(harness.feedback.alerts.isEmpty)
        XCTAssertNil(harness.coordinator.pendingNotification)
    }

    func testStoppingARunningTimerCancelsItsNotification() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .allowed)
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)

        timer.stopAndReset()

        XCTAssertEqual(harness.scheduler.cancelled, harness.scheduler.scheduled.map(\.identifier))
        XCTAssertNil(harness.coordinator.deadline)
    }

    // MARK: - Completion alerts

    func testOnTimeForegroundCompletionPlaysSoundAndHapticOnceAndRemovesNotification() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .allowed)
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)

        harness.clock.date = start.addingTimeInterval(60.4)
        XCTAssertTrue(timer.refreshCountdown(at: harness.clock.date))
        XCTAssertFalse(timer.refreshCountdown(at: harness.clock.date.addingTimeInterval(1)))

        XCTAssertEqual(harness.feedback.alerts, [.soundAndHaptic])
        XCTAssertEqual(harness.scheduler.cancelled, [harness.scheduler.scheduled[0].identifier])
        XCTAssertEqual(timer.state, .notStarted)
        XCTAssertNil(harness.coordinator.pendingNotification)
    }

    func testBackgroundCompletionLeavesNotificationToWatchOSAndStaysSilentOnReturn() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .allowed)
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)
        harness.coordinator.sceneDidChange(isActive: false, at: start.addingTimeInterval(5))

        // A tick that still fires off screen completes the countdown.
        harness.clock.date = start.addingTimeInterval(60.2)
        XCTAssertTrue(timer.refreshCountdown(at: harness.clock.date))

        XCTAssertTrue(harness.feedback.alerts.isEmpty)
        XCTAssertTrue(harness.scheduler.cancelled.isEmpty, "The pending request must stay for watchOS to deliver.")

        harness.clock.date = start.addingTimeInterval(300)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date)
        XCTAssertTrue(harness.feedback.alerts.isEmpty, "Returning must not replay an alert the notification delivered.")
        XCTAssertEqual(harness.scheduler.scheduled.count, 1)
    }

    func testLateForegroundReconciliationDoesNotDuplicateTheDeliveredNotification() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .allowed)
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)
        harness.coordinator.sceneDidChange(isActive: false, at: start.addingTimeInterval(5))

        // Suspended: no ticks until the wrist is raised two minutes later.
        harness.clock.date = start.addingTimeInterval(120)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date)

        XCTAssertTrue(harness.feedback.alerts.isEmpty)
        XCTAssertTrue(harness.scheduler.cancelled.isEmpty, "A background-owned request must remain available for delayed delivery.")
        XCTAssertEqual(timer.state, .notStarted)
        XCTAssertEqual(timer.timeRemaining, 60)
    }

    func testReturnJustAfterBackgroundDeadlineDoesNotReplayNotificationFeedback() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .allowed)
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)
        harness.coordinator.sceneDidChange(isActive: false, at: start.addingTimeInterval(5))

        // No tick while suspended; the accepted notification owns the deadline.
        harness.clock.date = start.addingTimeInterval(60.4)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date)
        harness.coordinator.reconcile(at: harness.clock.date.addingTimeInterval(1))

        XCTAssertTrue(harness.feedback.alerts.isEmpty, "Returning within the foreground tolerance must not replay a background alert.")
        XCTAssertEqual(timer.state, .notStarted)
    }

    func testFailedNotificationAddFallsBackToOneHapticOnLateReturn() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .allowed)
        harness.scheduler.rejectRequests = true
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)
        harness.coordinator.sceneDidChange(isActive: false, at: start.addingTimeInterval(5))

        harness.clock.date = start.addingTimeInterval(90)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date)
        harness.coordinator.sceneDidChange(isActive: false, at: harness.clock.date)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date)

        XCTAssertEqual(harness.feedback.alerts, [.haptic], "A rejected notification cannot own completion feedback.")
    }

    func testReturnBeforeDeadlineStillPlaysTheForegroundAlert() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .allowed)
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)
        let identifier = harness.coordinator.pendingNotification!.identifier
        harness.coordinator.sceneDidChange(isActive: false, at: start.addingTimeInterval(5))
        harness.clock.date = start.addingTimeInterval(59.5)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date)
        harness.clock.date = start.addingTimeInterval(60.4)
        timer.refreshCountdown(at: harness.clock.date)

        XCTAssertEqual(harness.feedback.alerts, [.soundAndHaptic])
        XCTAssertEqual(harness.coordinator.handleForegroundNotification(identifier: identifier, at: harness.clock.date), true)
        XCTAssertEqual(harness.feedback.alerts, [.soundAndHaptic])
    }

    func testDeniedNearDeadlineReturnPlaysOnlyOneHaptic() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .denied)
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)
        harness.coordinator.sceneDidChange(isActive: false, at: start.addingTimeInterval(5))
        harness.clock.date = start.addingTimeInterval(60.4)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date.addingTimeInterval(1))

        XCTAssertEqual(harness.feedback.alerts, [.haptic])
    }

    func testFailureAfterBackgroundCompletionDefersOneHapticUntilReturn() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .allowed)
        harness.scheduler.automaticallyCompleteAdds = false
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)
        let identifier = harness.coordinator.pendingNotification!.identifier
        harness.coordinator.sceneDidChange(isActive: false, at: start.addingTimeInterval(5))
        harness.clock.date = start.addingTimeInterval(61)
        timer.refreshCountdown(at: harness.clock.date)
        harness.scheduler.completeAdd(identifier: identifier, succeeded: false)
        XCTAssertTrue(harness.feedback.alerts.isEmpty)

        harness.clock.date = start.addingTimeInterval(90)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date)
        XCTAssertEqual(harness.feedback.alerts, [.haptic])
    }

    func testFailureAfterReturnPlaysOneHapticAndSuppressesTheFailedRequest() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .allowed)
        harness.scheduler.automaticallyCompleteAdds = false
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)
        let identifier = harness.coordinator.pendingNotification!.identifier
        harness.coordinator.sceneDidChange(isActive: false, at: start.addingTimeInterval(5))
        harness.clock.date = start.addingTimeInterval(60.4)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date)
        XCTAssertTrue(harness.feedback.alerts.isEmpty, "Wait for the unresolved add result.")

        harness.scheduler.completeAdd(identifier: identifier, succeeded: false)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date)
        XCTAssertEqual(harness.feedback.alerts, [.haptic])
        XCTAssertEqual(harness.coordinator.handleForegroundNotification(identifier: identifier, at: harness.clock.date), true)
    }

    func testCancelledAddFailureCannotClaimOrClearTheResumedRun() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .allowed)
        harness.scheduler.automaticallyCompleteAdds = false
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)
        let cancelled = harness.coordinator.pendingNotification!.identifier
        harness.clock.date = start.addingTimeInterval(10)
        timer.pause(at: harness.clock.date)
        harness.clock.date = start.addingTimeInterval(100)
        timer.play(at: harness.clock.date)
        let resumed = harness.coordinator.pendingNotification!.identifier

        harness.scheduler.completeAdd(identifier: cancelled, succeeded: false)
        XCTAssertEqual(harness.coordinator.pendingNotification?.identifier, resumed)
        XCTAssertTrue(harness.feedback.alerts.isEmpty)
        XCTAssertEqual(harness.coordinator.handleForegroundNotification(identifier: cancelled, at: harness.clock.date), true)
        harness.scheduler.completeAdd(identifier: resumed, succeeded: true)
    }

    func testFailedAddAfterInAppCompletionDoesNotReplayFeedback() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .allowed)
        harness.scheduler.automaticallyCompleteAdds = false
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)
        let identifier = harness.coordinator.pendingNotification!.identifier
        harness.clock.date = start.addingTimeInterval(60.4)
        timer.refreshCountdown(at: harness.clock.date)
        harness.scheduler.completeAdd(identifier: identifier, succeeded: false)

        XCTAssertEqual(harness.feedback.alerts, [.soundAndHaptic])
        XCTAssertEqual(harness.coordinator.handleForegroundNotification(identifier: identifier, at: harness.clock.date), true)
    }

    func testBackgroundOwnedNotificationCanPresentOnceAfterReturn() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .allowed)
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)
        let identifier = harness.coordinator.pendingNotification!.identifier
        harness.coordinator.sceneDidChange(isActive: false, at: start.addingTimeInterval(5))
        harness.clock.date = start.addingTimeInterval(60.4)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date)

        XCTAssertEqual(harness.coordinator.handleForegroundNotification(identifier: identifier, at: harness.clock.date), false)
        XCTAssertTrue(harness.feedback.alerts.isEmpty)
        XCTAssertEqual(harness.coordinator.handleForegroundNotification(identifier: identifier, at: harness.clock.date), true)
        XCTAssertNil(harness.coordinator.handleForegroundNotification(identifier: "unrelated", at: harness.clock.date))
    }

    func testObservedDeliveredNotificationDoesNotPresentAgain() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .allowed)
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)
        let identifier = harness.coordinator.pendingNotification!.identifier
        harness.coordinator.sceneDidChange(isActive: false, at: start.addingTimeInterval(5))
        harness.clock.date = start.addingTimeInterval(60.4)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date)
        harness.coordinator.recordDeliveredNotifications([identifier])

        XCTAssertEqual(harness.coordinator.handleForegroundNotification(identifier: identifier, at: harness.clock.date), true)
        XCTAssertTrue(harness.feedback.alerts.isEmpty)
    }

    func testDeniedPermissionNeverSchedulesAndTapsOnceForAMissedCompletion() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .denied)
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)
        XCTAssertTrue(harness.scheduler.scheduled.isEmpty)

        harness.coordinator.sceneDidChange(isActive: false, at: start.addingTimeInterval(5))
        harness.clock.date = start.addingTimeInterval(61)
        XCTAssertTrue(timer.refreshCountdown(at: harness.clock.date))
        XCTAssertTrue(harness.feedback.alerts.isEmpty, "No sound or haptic plays while off screen.")

        harness.clock.date = start.addingTimeInterval(200)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date)
        harness.coordinator.sceneDidChange(isActive: false, at: harness.clock.date)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date)

        XCTAssertEqual(harness.feedback.alerts, [.haptic])
        XCTAssertTrue(harness.scheduler.scheduled.isEmpty)
    }

    func testDeniedPermissionSuspendedReturnTapsOnceWithoutALateSound() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .denied)
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)
        harness.coordinator.sceneDidChange(isActive: false, at: start.addingTimeInterval(5))

        harness.clock.date = start.addingTimeInterval(90)
        harness.coordinator.sceneDidChange(isActive: true, at: harness.clock.date)

        XCTAssertEqual(harness.feedback.alerts, [.haptic])
    }

    func testPermissionChangesDuringARunScheduleOrCancelTheRemainingDeadline() {
        let timer = makeTimer(duration: 60)
        defer { timer.stopAndReset() }
        let harness = makeHarness(timer: timer, permission: .notDetermined)
        let start = Date(timeIntervalSince1970: 1_000)
        harness.clock.date = start
        timer.play(at: start)
        XCTAssertTrue(harness.scheduler.scheduled.isEmpty)

        harness.clock.date = start.addingTimeInterval(10)
        harness.coordinator.updatePermission(.allowed)
        harness.coordinator.updatePermission(.allowed)
        XCTAssertEqual(harness.scheduler.scheduled.map(\.fireDate), [start.addingTimeInterval(60)])

        harness.coordinator.updatePermission(.denied)
        XCTAssertEqual(harness.scheduler.cancelled, [harness.scheduler.scheduled[0].identifier])
        XCTAssertNil(harness.coordinator.pendingNotification)
    }

    func testCompletionAlertPolicy() {
        typealias Coordinator = WatchTimerAlertCoordinator
        XCTAssertEqual(Coordinator.completionAlert(isAppActive: true, lateness: 0.4, notificationScheduled: true), .soundAndHaptic)
        XCTAssertEqual(Coordinator.completionAlert(isAppActive: true, lateness: Coordinator.onTimeTolerance, notificationScheduled: false), .soundAndHaptic)
        XCTAssertEqual(Coordinator.completionAlert(isAppActive: true, lateness: 30, notificationScheduled: true), .none)
        XCTAssertEqual(Coordinator.completionAlert(isAppActive: true, lateness: 30, notificationScheduled: false), .haptic)
        XCTAssertEqual(Coordinator.completionAlert(isAppActive: false, lateness: 0, notificationScheduled: true), .none)
        XCTAssertEqual(Coordinator.completionAlert(isAppActive: false, lateness: 0, notificationScheduled: false), .none)
    }

    // MARK: - Sequence successor

    func testOverdueSessionPauseCompletesOnceAndSchedulesOnlyTheRunningSuccessor() {
        let timer = TimerViewModel()
        defer { timer.stopAndReset() }
        let game = GameViewModel(timerViewModel: timer)
        let harness = makeHarness(
            timer: timer,
            permission: .allowed,
            notificationText: { (game.currentRound?.name ?? "", game.gameSequence?.title ?? "") },
            afterFinish: { game.handleTimerFinished() }
        )
        var sequence = GameSequence(title: "Two Rounds", roundCount: 1)
        sequence.rounds = [
            Round(name: "First", durationSeconds: 60, startPaused: true, orderIndex: 0),
            Round(name: "Second", durationSeconds: 30, orderIndex: 1),
        ]
        game.loadGame(sequence)
        game.startGame()

        // The first round ran from two minutes ago; the wrist was down since.
        let started = Date().addingTimeInterval(-120)
        harness.clock.date = started
        timer.play(at: started)
        XCTAssertEqual(harness.scheduler.scheduled.map(\.title), ["First"])

        harness.clock.date = Date()
        timer.pause(at: harness.clock.date)

        XCTAssertEqual(game.currentRound?.name, "Second")
        XCTAssertEqual(timer.state, .running, "The overdue pause must not pause the successor.")
        XCTAssertEqual(timer.totalDuration, 30)
        XCTAssertEqual(harness.scheduler.scheduled.map(\.title), ["First", "Second"])
        XCTAssertEqual(harness.scheduler.cancelled, [harness.scheduler.scheduled[0].identifier])
        XCTAssertEqual(harness.coordinator.pendingNotification?.identifier, harness.scheduler.scheduled[1].identifier)
        XCTAssertTrue(harness.feedback.alerts.isEmpty, "The late round was already covered by its notification.")
    }

    // MARK: - Quick timer

    func testQuickTimerDigitsCountDownWhileTheConfiguredDurationStaysFixed() {
        let timer = makeTimer(duration: 90)
        defer { timer.stopAndReset() }
        let viewModel = WatchQuickTimerViewModel(timer: timer)
        let start = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(viewModel.displayedSeconds(at: start), 90)
        XCTAssertEqual(viewModel.primaryControl, .start)
        XCTAssertFalse(viewModel.showsReset)

        viewModel.performPrimaryAction(at: start)
        XCTAssertEqual(viewModel.primaryControl, .pause)
        XCTAssertEqual(viewModel.displayedSeconds(at: start.addingTimeInterval(30.2)), 60)
        XCTAssertEqual(WatchTimeText.clock(viewModel.displayedSeconds(at: start.addingTimeInterval(30.2))), "01:00")
        XCTAssertEqual(timer.totalDuration, 90)

        viewModel.performPrimaryAction(at: start.addingTimeInterval(45))
        XCTAssertEqual(viewModel.primaryControl, .resume)
        XCTAssertTrue(viewModel.showsReset)
        XCTAssertEqual(viewModel.displayedSeconds(at: start.addingTimeInterval(500)), 45, "Paused digits stay frozen.")

        viewModel.reset()
        XCTAssertEqual(viewModel.primaryControl, .start)
        XCTAssertFalse(viewModel.showsReset)
        XCTAssertEqual(viewModel.displayedSeconds(at: start.addingTimeInterval(600)), 90)
    }

    func testDigitalCrownEditsTheSelectedComponentOnlyWhileIdle() {
        UserDefaults.standard.removeObject(forKey: "savedTimerDuration")
        defer { UserDefaults.standard.removeObject(forKey: "savedTimerDuration") }
        let timer = TimerViewModel()
        defer { timer.stopAndReset() }
        timer.setDuration(65)
        let viewModel = WatchQuickTimerViewModel(timer: timer)

        viewModel.toggleSelection(.seconds)
        XCTAssertEqual(viewModel.selectedComponent, .seconds)
        XCTAssertEqual(viewModel.crownValue, 5)
        XCTAssertEqual(timer.totalDuration, 65, "Selecting must not edit.")

        viewModel.crownValue = 20
        XCTAssertEqual(timer.totalDuration, 80)

        viewModel.toggleSelection(.minutes)
        XCTAssertEqual(viewModel.crownValue, 1)
        viewModel.crownValue = 3
        XCTAssertEqual(timer.totalDuration, 200)
        viewModel.crownValue = 75
        XCTAssertEqual(timer.totalDuration, 59 * 60 + 20)
        viewModel.adjust(.seconds, by: -1)
        XCTAssertEqual(timer.totalDuration, 59 * 60 + 19)

        viewModel.performPrimaryAction(at: Date(timeIntervalSince1970: 1_000))
        XCTAssertNil(viewModel.selectedComponent)
        XCTAssertFalse(viewModel.canEditDuration)

        viewModel.toggleSelection(.minutes)
        XCTAssertNil(viewModel.selectedComponent)
        viewModel.crownValue = 1
        viewModel.adjust(.seconds, by: 5)
        XCTAssertEqual(timer.totalDuration, 59 * 60 + 19, "Running and paused timers ignore crown edits.")

        viewModel.performPrimaryAction(at: Date(timeIntervalSince1970: 1_001))
        XCTAssertEqual(timer.state, .paused)
        viewModel.toggleSelection(.seconds)
        XCTAssertNil(viewModel.selectedComponent)
        viewModel.crownValue = 2
        viewModel.adjust(.minutes, by: 1)
        XCTAssertEqual(timer.totalDuration, 59 * 60 + 19, "Pausing must not enable duration editing.")
    }

    func testPrimaryControlMapsEveryTimerState() {
        XCTAssertEqual(WatchPrimaryControl(state: .notStarted), .start)
        XCTAssertEqual(WatchPrimaryControl(state: .running), .pause)
        XCTAssertEqual(WatchPrimaryControl(state: .paused), .resume)
        XCTAssertNil(WatchPrimaryControl(state: .finished))
        XCTAssertEqual(WatchPrimaryControl.start.title, Theme.Label.start)
        XCTAssertEqual(WatchPrimaryControl.pause.title, Theme.Label.pause)
        XCTAssertEqual(WatchPrimaryControl.resume.title, Theme.Label.resume)
    }

    // MARK: - Helpers

    private struct Harness {
        let coordinator: WatchTimerAlertCoordinator
        let scheduler: RecordingNotificationScheduler
        let feedback: RecordingCompletionFeedback
        let clock: TestClock
    }

    private func makeTimer(duration: Int) -> TimerViewModel {
        let timer = TimerViewModel()
        timer.reconfigureForRound(duration: duration, color: nil)
        return timer
    }

    private func makeHarness(
        timer: TimerViewModel,
        permission: WatchNotificationPermission,
        notificationText: @escaping () -> (title: String, body: String) = { ("Done", "") },
        afterFinish: (() -> Void)? = nil
    ) -> Harness {
        let scheduler = RecordingNotificationScheduler()
        let feedback = RecordingCompletionFeedback()
        let clock = TestClock()
        let coordinator = WatchTimerAlertCoordinator(
            timer: timer,
            scheduler: scheduler,
            feedback: feedback,
            identifierPrefix: "test",
            permission: permission,
            now: { clock.date },
            notificationText: notificationText,
            afterFinish: afterFinish
        )
        return Harness(coordinator: coordinator, scheduler: scheduler, feedback: feedback, clock: clock)
    }
}

@MainActor
private final class RecordingNotificationScheduler: WatchTimerNotificationScheduling {
    private(set) var scheduled: [WatchTimerNotification] = []
    private(set) var cancelled: [String] = []
    var rejectRequests = false
    var automaticallyCompleteAdds = true
    private var addCompletions: [String: @MainActor (Bool) -> Void] = [:]

    func schedule(_ notification: WatchTimerNotification, completion: @escaping @MainActor (Bool) -> Void) {
        scheduled.append(notification)
        if automaticallyCompleteAdds {
            completion(!rejectRequests)
        } else {
            addCompletions[notification.identifier] = completion
        }
    }

    func completeAdd(identifier: String, succeeded: Bool) {
        guard let completion = addCompletions.removeValue(forKey: identifier) else {
            XCTFail("No unresolved add for \(identifier)")
            return
        }
        completion(succeeded)
    }

    func cancel(identifier: String) {
        cancelled.append(identifier)
    }
}

@MainActor
private final class RecordingCompletionFeedback: WatchCompletionFeedback {
    private(set) var alerts: [WatchCompletionAlert] = []

    func play(_ alert: WatchCompletionAlert) {
        alerts.append(alert)
    }
}

@MainActor
private final class TestClock {
    var date = Date(timeIntervalSince1970: 0)
}

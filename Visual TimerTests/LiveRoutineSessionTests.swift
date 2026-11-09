import XCTest
@testable import Visual_Timer

@MainActor
final class LiveRoutineSessionTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1000)
    private func state(paused: Bool = false, repeats: Int = 1) throws -> LiveRoutineSession {
        try LiveRoutineSession(plan: GameSequence(title: "Routine", rounds: [
            Round(name: "One", durationSeconds: 10, startPaused: paused),
            Round(name: "Two", durationSeconds: 20, orderIndex: 1)
        ], roundCount: repeats), authority: UUID(), now: date)
    }
    private func command(_ state: LiveRoutineSession, _ action: LiveRoutineCommand.Action) -> LiveRoutineCommand {
        LiveRoutineCommand(session: state.id, revision: state.revision, occurrence: state.occurrence, action: action)
    }
    func testExpiryRejectsPauseAndNextOnSuccessor() throws {
        for action in [LiveRoutineCommand.Action.pause, .next] {
            var value = try state()
            XCTAssertFalse(value.apply(command(value, action), at: date.addingTimeInterval(11)))
            XCTAssertEqual(value.step, 1)
            XCTAssertEqual(value.phase, .running)
            XCTAssertEqual(value.elapsed(at: date.addingTimeInterval(11)), 0)
        }
    }
    func testRetryAndSimultaneousCommandsApplyOnce() throws {
        var value = try state()
        let next = command(value, .next)
        let pause = command(value, .pause)
        XCTAssertTrue(value.apply(next, at: date))
        XCTAssertFalse(value.apply(next, at: date))
        XCTAssertFalse(value.apply(pause, at: date))
        XCTAssertEqual(value.step, 1)
    }
    func testWakeOnlyAdvancesOneStep() throws {
        var value = try state(repeats: 3)
        value.reconcile(at: date.addingTimeInterval(500))
        XCTAssertEqual(value.step, 1)
        XCTAssertEqual(value.repetition, 1)
        XCTAssertEqual(value.anchor, date.addingTimeInterval(500))
    }
    func testStartPausedAndRepeat() throws {
        var value = try state(paused: true, repeats: 2)
        XCTAssertFalse(value.reconcile(at: date.addingTimeInterval(100)))
        XCTAssertTrue(value.apply(command(value, .resume), at: date))
        value.reconcile(at: date.addingTimeInterval(10))
        value.reconcile(at: date.addingTimeInterval(30))
        XCTAssertEqual(value.repetition, 2)
        XCTAssertEqual(value.phase, .waiting)
    }
    func testTerminalRejectsOldMessagesAfterJournalRoundTrip() throws {
        var value = try state()
        let old = value
        XCTAssertTrue(value.apply(command(value, .end), at: date))
        var journal = LiveRoutineJournal(current: value)
        journal = try JSONDecoder().decode(LiveRoutineJournal.self, from: JSONEncoder().encode(journal))
        XCTAssertFalse(journal.receive(old))
        XCTAssertTrue(journal.current!.terminal)
    }
    func testOfflineIndependentSessionsBecomeConflict() throws {
        let first = try state()
        let second = try state()
        var journal = LiveRoutineJournal(current: first)
        XCTAssertFalse(journal.receive(second))
        XCTAssertEqual(journal.current?.id, first.id)
        XCTAssertEqual(journal.conflict?.id, second.id)
    }
    func testReorderedSnapshotAndChangedPlanRejected() throws {
        var latest = try state()
        let old = latest
        _ = latest.apply(command(latest, .next), at: date)
        var journal = LiveRoutineJournal(current: old)
        XCTAssertTrue(journal.receive(latest))
        XCTAssertFalse(journal.receive(old))
        XCTAssertEqual(journal.current?.step, 1)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(latest)) as? [String: Any])
        var plan = try XCTUnwrap(json["plan"] as? [String: Any])
        plan["title"] = "Changed while running"
        json["plan"] = plan
        let mutated = try JSONDecoder().decode(LiveRoutineSession.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(journal.receive(mutated))
    }
    func testPlanSurvivesSourceMutation() throws {
        var source = try state().plan
        let value = try LiveRoutineSession(plan: source, authority: UUID(), now: date)
        source.rounds.removeAll()
        XCTAssertEqual(value.plan.activeRounds.count, 2)
        XCTAssertTrue(value.valid())
    }
    func testUnknownVersionRejected() throws {
        let value = try state()
        let data = try JSONEncoder().encode(value)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["version"] = 2
        let future = try JSONDecoder().decode(LiveRoutineSession.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(future.valid())
    }
}

@MainActor
private final class RoutineTestTransport: LiveRoutineTransport {
    var receiveLive: ((Data) -> Void)?
    var receiveCommand: ((Data, @escaping (Data) -> Void) -> Void)?
    var connectionChanged: (() -> Void)?
    var reachable = true
    var peer: RoutineTestTransport?
    var context: Data?
    var dropReply = false
    var delayed: [Data] = []
    func activate() {}
    func replayLiveContext() { if let data = peer?.context { receiveLive?(data) } }
    func publishLive(_ data: Data) { context = data }
    func sendLiveCommand(_ data: Data, completion: @escaping (Data?) -> Void) {
        guard reachable, let peer else { completion(nil); return }
        peer.receiveCommand?(data) { [weak self] reply in completion(self?.dropReply == true ? nil : reply) }
    }
    func deliver() { if let context { peer?.receiveLive?(context) } }
}

@MainActor
final class LiveRoutineIntegrationTests: XCTestCase {
    private func directory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    private func plan() -> GameSequence {
        GameSequence(title: "Routine", rounds: [Round(name: "One", durationSeconds: 10), Round(name: "Two", durationSeconds: 20, orderIndex: 1)])
    }
    func testAcknowledgedRemoteControlAndReconnect() {
        let a = RoutineTestTransport(), b = RoutineTestTransport()
        a.peer = b; b.peer = a
        let owner = LiveRoutineController(directory: directory(), transport: a)
        let replica = LiveRoutineController(directory: directory(), transport: b)
        owner.start(plan()); a.deliver(); replica.activate()
        XCTAssertTrue(replica.canControl)
        replica.perform(.next)
        XCTAssertEqual(owner.journal.current?.step, 1)
        XCTAssertEqual(replica.journal.current?.step, 1)
        XCTAssertNil(replica.pending)
        b.reachable = false; b.connectionChanged?()
        replica.perform(.pause)
        XCTAssertEqual(owner.journal.current?.phase, .running)
        b.reachable = true; b.connectionChanged?()
        XCTAssertTrue(replica.canControl)
    }
    func testOwnerUsesMonotonicTimeAcrossWallJumpAndOnlyOneExpiry() {
        var wall = Date(timeIntervalSince1970: 1000)
        var continuous: TimeInterval = 100
        let controller = LiveRoutineController(directory: directory(), transport: RoutineTestTransport(),
            clock: RoutineClock(wall: { wall }, continuous: { continuous }))
        var feedback = 0
        controller.expired = { feedback += 1 }
        controller.start(plan())
        wall = wall.addingTimeInterval(3600); continuous += 5
        controller.tick()
        XCTAssertEqual(controller.journal.current?.step, 0)
        continuous += 100
        controller.tick()
        XCTAssertEqual(controller.journal.current?.step, 1)
        XCTAssertEqual(feedback, 1)
    }
    func testReplicaDoesNotExpireOrWriteHistoryAndOwnerWritesOnce() {
        let a = RoutineTestTransport(), b = RoutineTestTransport()
        a.peer = b; b.peer = a
        let owner = LiveRoutineController(directory: directory(), transport: a)
        let replica = LiveRoutineController(directory: directory(), transport: b)
        var ownerRecords = 0, replicaRecords = 0
        owner.saveHistory = { _ in ownerRecords += 1; return true }
        replica.saveHistory = { _ in replicaRecords += 1; return true }
        owner.start(plan()); a.deliver(); replica.activate()
        replica.tick()
        owner.perform(.end); a.deliver()
        owner.commitHistoryIfNeeded(); replica.commitHistoryIfNeeded()
        XCTAssertEqual(ownerRecords, 1)
        XCTAssertEqual(replicaRecords, 0)
        owner.dismiss()
        XCTAssertNil(owner.journal.current)
    }
    func testConflictPersistsAndTerminalCannotResurrect() {
        let a = RoutineTestTransport(), b = RoutineTestTransport()
        a.peer = b; b.peer = a
        let folder = directory()
        let owner = LiveRoutineController(directory: folder, transport: a)
        let other = LiveRoutineController(directory: directory(), transport: b)
        owner.start(plan()); other.start(plan()); b.deliver()
        XCTAssertNotNil(owner.journal.conflict)
        let restored = LiveRoutineController(directory: folder, transport: RoutineTestTransport())
        XCTAssertNotNil(restored.journal.conflict)
        XCTAssertEqual(restored.journal.device, owner.journal.device)
        let old = a.context!
        other.perform(.end); other.dismiss()
        a.deliver()
        let replicaFolder = directory()
        let replicaTransport = RoutineTestTransport()
        let replica = LiveRoutineController(directory: replicaFolder, transport: replicaTransport)
        replicaTransport.receiveLive?(old)
        owner.perform(.end); a.deliver()
        replicaTransport.receiveLive?(a.context!)
        replica.dismiss()
        replicaTransport.receiveLive?(old)
        XCTAssertNil(replica.journal.current)
    }
    func testQuickTimerStillFinishesWithLiveController() {
        let timer = TimerViewModel()
        let model = GameViewModel(timerViewModel: timer, historyStore: HistoryStore(documentsDirectory: directory()))
        model.enableLiveSync(directory: directory(), transport: RoutineTestTransport())
        var finishes = 0
        timer.onFinish = { finishes += 1 }
        timer.setDuration(5)
        let date = Date()
        timer.play(at: date)
        XCTAssertTrue(timer.refreshCountdown(at: date.addingTimeInterval(6)))
        XCTAssertEqual(finishes, 1)
        XCTAssertEqual(timer.state, .notStarted)
    }
    func testTerminalDoneAndGoAgainUseNewIdentity() {
        let model = GameViewModel(timerViewModel: TimerViewModel(), historyStore: HistoryStore(documentsDirectory: directory()))
        model.enableLiveSync(directory: directory(), transport: RoutineTestTransport())
        model.loadGame(plan())
        let first = model.live?.journal.current?.id
        model.endGame()
        XCTAssertEqual(model.gamePhase, .gameOver)
        model.addRoundDuringGameOver()
        XCTAssertNotEqual(model.live?.journal.current?.id, first)
        model.endGame(); model.endGame()
        XCTAssertEqual(model.gamePhase, .idle)
    }
    func testContextCompositionKeepsLiveWhenTemplatesUseFile() {
        let live = Data([1, 2, 3])
        let context = WatchTemplateConnectivity.composedContext(templates: [WatchTemplateStore.contextKey: Data(repeating: 1, count: 100_000)], live: live)
        XCTAssertEqual(context[WatchTemplateConnectivity.liveKey] as? Data, live)
        XCTAssertNil(context[WatchTemplateStore.contextKey])
    }
}

extension LiveRoutineIntegrationTests {
    func testLostAcknowledgementConvergesWithoutReplayingAction() {
        let a = RoutineTestTransport(), b = RoutineTestTransport()
        a.peer = b; b.peer = a
        let owner = LiveRoutineController(directory: directory(), transport: a)
        let replica = LiveRoutineController(directory: directory(), transport: b)
        owner.start(plan()); a.deliver(); replica.activate()
        b.dropReply = true
        replica.perform(.next)
        XCTAssertEqual(owner.journal.current?.step, 1)
        XCTAssertNotNil(replica.note)
        a.deliver()
        XCTAssertEqual(replica.journal.current?.step, 1)
        XCTAssertEqual(owner.journal.current?.revision, 2)
    }
    func testRemoteRoutineDoesNotReplaceRunningQuickTimer() {
        let a = RoutineTestTransport(), b = RoutineTestTransport()
        a.peer = b; b.peer = a
        let owner = LiveRoutineController(directory: directory(), transport: a)
        let timer = TimerViewModel()
        let phone = GameViewModel(timerViewModel: timer, historyStore: HistoryStore(documentsDirectory: directory()))
        phone.enableLiveSync(directory: directory(), transport: b)
        timer.setDuration(300); timer.play()
        owner.start(plan()); a.deliver()
        XCTAssertEqual(phone.gamePhase, .idle)
        XCTAssertEqual(timer.totalDuration, 300)
        XCTAssertEqual(timer.state, .running)
        XCTAssertTrue(phone.availableRemoteRoutine)
    }
    func testLegacySessionKeepsControlsAfterEnablingSync() {
        let folder = directory()
        let timer = TimerViewModel()
        let phone = GameViewModel(timerViewModel: timer, historyStore: HistoryStore(documentsDirectory: folder))
        phone.loadGame(plan()); phone.startGame()
        phone.enableLiveSync(directory: folder, transport: RoutineTestTransport())
        XCTAssertFalse(phone.isLiveSession)
        phone.skipCurrentRound()
        XCTAssertEqual(phone.currentRoundIndex, 1)
        phone.endGame()
        XCTAssertEqual(phone.gamePhase, .idle)
    }
    func testRecoveryUsesMonotonicClockAfterWallClockChange() {
        let folder = directory()
        var wall = Date(timeIntervalSince1970: 1000)
        var continuous: TimeInterval = 100
        let clock = RoutineClock(boot: { "same-boot" }, wall: { wall }, continuous: { continuous })
        let owner = LiveRoutineController(directory: folder, transport: RoutineTestTransport(), clock: clock)
        owner.start(plan())
        wall = wall.addingTimeInterval(3600); continuous += 5
        let restored = LiveRoutineController(directory: folder, transport: RoutineTestTransport(), clock: clock)
        restored.tick()
        XCTAssertEqual(restored.journal.current?.step, 0)
        XCTAssertEqual(restored.journal.current?.elapsed(at: restored.now), 5)
    }
    func testCorruptStepJournalDoesNotCrashOrChangeIdentity() throws {
        let folder = directory()
        let owner = LiveRoutineController(directory: folder, transport: RoutineTestTransport())
        owner.start(plan())
        let identity = owner.journal.device
        var journal = owner.journal
        journal.current?.step = 999
        try JSONEncoder().encode(journal).write(to: folder.appendingPathComponent("LiveRoutine.json"))
        let restored = LiveRoutineController(directory: folder, transport: RoutineTestTransport())
        XCTAssertNil(restored.journal.current)
        XCTAssertEqual(restored.journal.device, identity)
    }
}

extension LiveRoutineIntegrationTests {
    func testUnjoinedRemoteDoesNotBecomeJoinedAfterRelaunch() {
        let a = RoutineTestTransport(), b = RoutineTestTransport()
        a.peer = b; b.peer = a
        let folder = directory()
        let owner = LiveRoutineController(directory: directory(), transport: a)
        let phone = GameViewModel(timerViewModel: TimerViewModel(), historyStore: HistoryStore(documentsDirectory: folder))
        phone.enableLiveSync(directory: folder, transport: b)
        owner.start(plan()); a.deliver()
        let restored = GameViewModel(timerViewModel: TimerViewModel(), historyStore: HistoryStore(documentsDirectory: folder))
        restored.enableLiveSync(directory: folder, transport: RoutineTestTransport())
        XCTAssertFalse(restored.isLiveSession)
        XCTAssertEqual(restored.gamePhase, .idle)
        XCTAssertFalse(restored.restoreSavedSession())
        XCTAssertTrue(restored.availableRemoteRoutine)
    }
    func testFailedEndAndStartDoesNotStartWhenOldSessionEventuallyEnds() {
        let a = RoutineTestTransport(), b = RoutineTestTransport()
        a.peer = b; b.peer = a
        let owner = LiveRoutineController(directory: directory(), transport: a)
        let folder = directory()
        let replica = GameViewModel(timerViewModel: TimerViewModel(), historyStore: HistoryStore(documentsDirectory: folder))
        replica.enableLiveSync(directory: folder, transport: b)
        owner.start(plan()); a.deliver(); replica.joinRemoteRoutine()
        replica.loadGame(GameSequence(title: "Replacement", rounds: [Round(name: "New", durationSeconds: 5)]))
        // The endpoint disappears after reachability was checked. No command
        // is delivered, and the later terminal context must not start anything.
        b.peer = nil
        replica.confirmReplacement()
        let oldID = owner.journal.current?.id
        owner.perform(.end); a.deliver()
        XCTAssertEqual(replica.live?.journal.current?.id, oldID)
        XCTAssertTrue(replica.live?.journal.current?.terminal == true)
    }
    func testContinuousClockCountsSuspensionAndCommandExpiryFeedback() {
        var continuous: TimeInterval = 100
        let controller = LiveRoutineController(directory: directory(), transport: RoutineTestTransport(),
            clock: RoutineClock(wall: { Date(timeIntervalSince1970: 1000) }, continuous: { continuous }))
        var feedback = 0
        controller.expired = { feedback += 1 }
        controller.start(plan())
        // No callbacks during sleep. The continuous clock includes that time.
        continuous += 300
        controller.perform(.pause)
        XCTAssertEqual(controller.journal.current?.step, 1)
        XCTAssertEqual(controller.journal.current?.phase, .running)
        XCTAssertEqual(feedback, 1)
    }
    func testLiveDisplayKeepsDeadlineStableAcrossSmallSamplingDifferences() {
        let timer = TimerViewModel()
        let date = Date()
        let progress = TimerVisualProgress(totalDuration: 10).running(from: date)
        timer.restore(totalDuration: 10, progress: progress, state: .running, color: nil)
        let finish = timer.visualProgress.finishDate
        timer.updateLiveDisplay(TimerVisualProgress(totalDuration: 10).running(from: date.addingTimeInterval(0.001)))
        XCTAssertEqual(timer.visualProgress.finishDate, finish)
    }
}

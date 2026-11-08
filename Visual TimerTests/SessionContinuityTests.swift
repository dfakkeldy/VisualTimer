import XCTest
@testable import Visual_Timer

/// Covers what the session screens now show and keep: the next round for any
/// sequence, time left in the session, restoring after the app closes, and
/// the History timeline.
final class SessionContinuityTests: XCTestCase {

    private func routine(repeats: Int = 1) -> GameSequence {
        var game = GameSequence(title: "Routine", roundCount: repeats)
        game.rounds = [
            Round(name: "Wash", durationSeconds: 60, orderIndex: 0, countsAsPlayer: false),
            Round(name: "Dress", durationSeconds: 120, orderIndex: 1, countsAsPlayer: false),
            Round(name: "Eat", durationSeconds: 300, orderIndex: 2, countsAsPlayer: false),
        ]
        return game
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testNextRoundIncludesRoundsThatAreNotTurns() {
        let game = GameViewModel(timerViewModel: TimerViewModel())
        game.loadGame(routine())
        game.startGame()

        XCTAssertNil(game.nextPlayer, "Routine steps don't count as turns")
        XCTAssertEqual(game.nextRound?.name, "Dress")
        XCTAssertEqual(game.roundProgressText, "Step 1 of 3")
    }

    func testNextRoundWrapsIntoTheNextRepeatAndEndsOnTheLast() {
        let game = GameViewModel(timerViewModel: TimerViewModel())
        game.loadGame(routine(repeats: 2))
        game.startGame()
        game.skipCurrentRound()
        game.skipCurrentRound()

        XCTAssertEqual(game.currentRound?.name, "Eat")
        XCTAssertEqual(game.nextRound?.name, "Wash", "Wraps into repeat 2")

        game.skipCurrentRound()
        game.skipCurrentRound()
        game.skipCurrentRound()
        XCTAssertEqual(game.currentRound?.name, "Eat")
        XCTAssertNil(game.nextRound, "Nothing follows the last round of the last repeat")
    }

    func testRemainingSessionSecondsCountsLaterRoundsAndRepeats() {
        let game = GameViewModel(timerViewModel: TimerViewModel())
        game.loadGame(routine(repeats: 2))
        game.startGame()

        // 30 s left in Wash, then Dress and Eat, then one more full pass of 480 s.
        XCTAssertEqual(game.remainingSessionSeconds(currentRemaining: 30), 30 + 120 + 300 + 480)
    }

    func testSessionRestoresAfterTheAppCloses() throws {
        let directory = try temporaryDirectory()
        let store = ActiveSessionStore(directory: directory)

        let first = GameViewModel(timerViewModel: TimerViewModel())
        first.sessionStore = store
        first.loadGame(routine())
        first.startGame()
        first.skipCurrentRound()
        first.timerViewModel.pause()
        first.recordPause()

        let second = GameViewModel(timerViewModel: TimerViewModel())
        second.sessionStore = store
        XCTAssertTrue(second.restoreSavedSession())
        XCTAssertEqual(second.gamePhase, .playing)
        XCTAssertEqual(second.currentRound?.name, "Dress")
        XCTAssertEqual(second.timerViewModel.state, .paused)
        XCTAssertEqual(second.timerViewModel.totalDuration, 120)
        XCTAssertEqual(second.sessionEvents.count, first.sessionEvents.count)
    }

    func testRestoreNeverReplacesASessionInProgress() throws {
        let store = ActiveSessionStore(directory: try temporaryDirectory())
        let saver = GameViewModel(timerViewModel: TimerViewModel())
        saver.sessionStore = store
        saver.loadGame(routine())
        saver.startGame()

        let busy = GameViewModel(timerViewModel: TimerViewModel())
        busy.sessionStore = store
        var other = routine()
        other.title = "Other"
        busy.loadGame(other)
        busy.startGame()

        XCTAssertFalse(busy.restoreSavedSession())
        XCTAssertEqual(busy.gameSequence?.title, "Other")
    }

    func testEndingOrFinishingClearsTheSavedSession() throws {
        let store = ActiveSessionStore(directory: try temporaryDirectory())
        let game = GameViewModel(timerViewModel: TimerViewModel())
        game.sessionStore = store
        game.loadGame(routine())
        game.startGame()
        XCTAssertNotNil(store.load())

        game.endGame()
        XCTAssertNil(store.load())
    }

    func testMalformedSavedSessionIsDiscarded() throws {
        let directory = try temporaryDirectory()
        try Data("not json".utf8).write(to: directory.appendingPathComponent("ActiveSession.json"))
        let store = ActiveSessionStore(directory: directory)

        let game = GameViewModel(timerViewModel: TimerViewModel())
        game.sessionStore = store
        XCTAssertFalse(game.restoreSavedSession())
        XCTAssertNil(store.load())
        XCTAssertEqual(game.gamePhase, .idle)
    }

    func testTimerRestoreIsGuardedAndKeepsRemainingTime() {
        let timer = TimerViewModel()
        let start = Date().addingTimeInterval(-40)
        let progress = TimerVisualProgress(totalDuration: 100).running(from: start).paused(at: start.addingTimeInterval(40))

        timer.restore(totalDuration: 100, progress: progress, state: .paused, color: nil)
        XCTAssertEqual(timer.state, .paused)
        XCTAssertEqual(timer.timeRemaining, 60)

        timer.play()
        timer.restore(totalDuration: 100, progress: TimerVisualProgress(totalDuration: 100), state: .paused, color: nil)
        XCTAssertEqual(timer.state, .running, "Restore never interrupts a running timer")
        timer.pause()
    }

    func testTimelineFoldsEventsIntoOneItemPerRound() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        let events: [SessionEvent] = [
            .gameStarted(timestamp: t0),
            .roundStarted(playerName: "Maya", emoji: "🦊", timestamp: t0),
            .paused(timestamp: t0.addingTimeInterval(10)),
            .resumed(timestamp: t0.addingTimeInterval(20)),
            .roundFinished(playerName: "Maya", timestamp: t0.addingTimeInterval(90)),
            .roundStarted(playerName: "Theo", emoji: "🐢", timestamp: t0.addingTimeInterval(90)),
            .skipped(playerName: "Theo", timestamp: t0.addingTimeInterval(100)),
            .gameEnded(timestamp: t0.addingTimeInterval(100)),
        ]
        let record = GameRecord(id: UUID(), gameTitle: "Night", session: GameSession(events: events), playerNames: ["Maya", "Theo"], playedAt: t0)

        let items = SessionTimeline(record: record).items
        XCTAssertEqual(items.map(\.name), ["Maya", "Theo", "Finished"])
        XCTAssertEqual(items[0].length, 90)
        XCTAssertEqual(items[0].note, "1 pause")
        XCTAssertEqual(items[1].length, 10)
        XCTAssertEqual(items[1].note, "Skipped")
    }

    func testGoAgainIsRecordedAsItsOwnSession() throws {
        let directory = try temporaryDirectory()
        let history = HistoryStore(documentsDirectory: directory)
        let game = GameViewModel(timerViewModel: TimerViewModel(), historyStore: history)
        game.loadGame(routine())
        game.startGame()
        for _ in 0..<3 { game.handleTimerFinished() }
        XCTAssertEqual(game.gamePhase, .gameOver)
        XCTAssertTrue(game.lastRecordSaved)
        XCTAssertEqual(history.loadAll().count, 1)

        game.addRoundDuringGameOver()
        XCTAssertFalse(game.lastRecordSaved, "The extra pass isn't saved yet")
        for _ in 0..<3 { game.handleTimerFinished() }
        XCTAssertTrue(game.lastRecordSaved)
        XCTAssertEqual(history.loadAll().count, 2)
        XCTAssertEqual(game.stepsRunCount, 3, "The finish counts this pass's steps, like its time")
    }

    func testTimerTextReadsPlainly() {
        XCTAssertEqual(TimerText.clock(300), "05:00")
        XCTAssertEqual(TimerText.length(541), "9:01")
        XCTAssertEqual(TimerText.words(45), "45 sec")
        XCTAssertEqual(TimerText.words(1935), "32 min")
        XCTAssertEqual(TimerText.approximateLeft(30), "under a minute left")
    }
}

import SwiftUI
import Combine

// MARK: - Game Phase

enum GamePhase {
    /// No game loaded or game ended — single-timer mode.
    case idle
    /// A game is loaded and ready to start.
    case ready
    /// The game sequence is playing.
    case playing
    /// All rounds have completed.
    case gameOver
}

// MARK: - Game View Model

final class GameViewModel: ObservableObject {

    // MARK: - Published State

    @Published var gamePhase: GamePhase = .idle
    @Published var gameSequence: GameSequence?
    @Published var currentRoundIndex: Int = 0
    @Published var currentRound: Round?
    @Published var currentOverallRound: Int = 1
    @Published var totalRoundCount: Int = 1
    @Published var sessionEvents: [SessionEvent] = []
    @Published var gameElapsedTime: TimeInterval = 0
    /// Shown once after a session is restored, until the next action:
    /// where the person stopped, in plain words.
    @Published var resumeNote: String?
    /// Whether the last finished or ended session reached History.
    @Published private(set) var lastRecordSaved = false

    /// The timer view model that does the actual countdown.
    let timerViewModel: TimerViewModel

    /// Plays the finish sound when rounds complete.
    weak var soundManager: SoundManager?

    private let historyStore: HistoryStore
    private let onHistoryRecordSaved: ((GameRecord) -> Void)?

    /// When set, the running session is saved after every change and can be
    /// restored after the app is closed. The iPhone app sets it; the Watch doesn't.
    var sessionStore: ActiveSessionStore?

    /// Wall-clock time when the game started. Used for event timestamps.
    private var gameStartDate: Date?
    /// 1 Hz timer that increments `gameElapsedTime`.
    private var elapsedTimer: AnyCancellable?

    // MARK: - Computed

    var hasActiveGame: Bool {
        gamePhase != .idle
    }

    var activeRounds: [Round] {
        gameSequence?.activeRounds ?? []
    }

    var currentRoundNumber: Int {
        currentRoundIndex + 1
    }

    var totalRounds: Int {
        activeRounds.count
    }

    /// The next active round whose `countsAsPlayer` is true.
    /// Wraps across cycles if roundCount > 1. Returns nil on
    /// the last player of the last cycle.
    var nextPlayer: Round? {
        let rounds = activeRounds
        guard !rounds.isEmpty else { return nil }
        var searchIndex = currentRoundIndex + 1
        for _ in 0..<rounds.count {
            if searchIndex >= rounds.count {
                if currentOverallRound < totalRoundCount {
                    searchIndex = 0
                } else {
                    return nil
                }
            }
            let candidate = rounds[searchIndex]
            if candidate.countsAsPlayer {
                return candidate
            }
            searchIndex += 1
        }
        return nil
    }

    /// Number of active rounds where `countsAsPlayer` is true.
    var countingPlayerCount: Int {
        activeRounds.filter(\.countsAsPlayer).count
    }

    /// 1-based index of the current round among counting players only.
    var countingPlayerIndex: Int {
        let rounds = activeRounds
        guard !rounds.isEmpty else { return 0 }
        var count = 0
        for i in 0...min(currentRoundIndex, rounds.count - 1) {
            if rounds[i].countsAsPlayer {
                count += 1
            }
        }
        return max(count, 1)
    }

    var roundProgressText: String {
        if countingPlayerCount > 0 {
            return "Turn \(countingPlayerIndex) of \(countingPlayerCount)"
        }
        return "Step \(currentRoundNumber) of \(totalRounds)"
    }

    /// The next active round in play order, whatever its type, so routines and
    /// breaks preview what comes next too. Wraps into the next repeat; nil on
    /// the last round of the last repeat.
    var nextRound: Round? {
        let rounds = activeRounds
        guard !rounds.isEmpty else { return nil }
        let next = currentRoundIndex + 1
        if next < rounds.count { return rounds[next] }
        return currentOverallRound < totalRoundCount ? rounds[0] : nil
    }

    /// Seconds left in the whole session: the current round's remaining time
    /// plus every round still to come, including later repeats.
    func remainingSessionSeconds(currentRemaining: Int) -> Int {
        let rounds = activeRounds
        guard !rounds.isEmpty else { return 0 }
        let laterThisPass = rounds.dropFirst(currentRoundIndex + 1).reduce(0) { $0 + $1.durationSeconds }
        let perPass = rounds.reduce(0) { $0 + $1.durationSeconds }
        let laterPasses = max(totalRoundCount - currentOverallRound, 0) * perPass
        return max(currentRemaining, 0) + laterThisPass + laterPasses
    }

    /// Rounds this session ran to an end, finished or skipped.
    var stepsRunCount: Int {
        sessionEvents.reduce(0) { count, event in
            switch event {
            case .roundFinished, .skipped: return count + 1
            default: return count
            }
        }
    }

    /// Rounds skipped in the session so far.
    var skippedCount: Int {
        GameSession(events: sessionEvents).skipCount
    }

    /// Wall-clock length of the session that just finished or is running,
    /// from its first to its last recorded event.
    var sessionDurationSeconds: TimeInterval {
        GameSession(events: sessionEvents).totalElapsedSeconds
    }

    // MARK: - Init

    init(
        timerViewModel: TimerViewModel,
        soundManager: SoundManager? = nil,
        historyStore: HistoryStore = HistoryStore(),
        onHistoryRecordSaved: ((GameRecord) -> Void)? = nil
    ) {
        self.timerViewModel = timerViewModel
        self.soundManager = soundManager
        self.historyStore = historyStore
        self.onHistoryRecordSaved = onHistoryRecordSaved
    }

    // MARK: - Game Lifecycle

    /// Loading over a session in progress ends it the way End does, so it
    /// reaches History rather than vanishing.
    func loadGame(_ game: GameSequence) {
        guard !game.activeRounds.isEmpty else { return }
        endGame(clearState: true)
        gameSequence = game
        currentRoundIndex = 0
        gamePhase = .ready
    }

    func startGame() {
        guard let game = gameSequence,
              gamePhase == .ready,
              !game.activeRounds.isEmpty else { return }
        gamePhase = .playing
        currentRoundIndex = 0
        currentOverallRound = 1
        totalRoundCount = max(game.roundCount, 1)
        gameStartDate = Date()
        gameElapsedTime = 0
        sessionEvents = []
        sessionEvents.append(.gameStarted(timestamp: gameStartDate!))
        startElapsedTimer()
        configureTimerForCurrentRound(autoStart: true)
    }

    func endGame(clearState: Bool = false) {
        resetSession(clearState: clearState, saveRecord: true)
    }

    // MARK: - Round Advancement

    /// Called by the unified onFinish handler when a round's timer hits zero.
    func handleTimerFinished() {
        guard gamePhase == .playing else { return }
        if let round = currentRound {
            sessionEvents.append(.roundFinished(playerName: round.name, timestamp: Date()))
        }
        advanceToNextRound()
    }

    private func advanceToNextRound() {
        let rounds = activeRounds
        let nextIndex = currentRoundIndex + 1

        if nextIndex < rounds.count {
            currentRoundIndex = nextIndex
            configureTimerForCurrentRound(autoStart: true)
        } else if currentOverallRound < totalRoundCount {
            currentOverallRound += 1
            currentRoundIndex = 0
            configureTimerForCurrentRound(autoStart: true)
        } else {
            completeGame()
        }
    }

    /// Replays the full active-round sequence once more from the beginning.
    func addRoundDuringGameOver() {
        guard gamePhase == .gameOver, !activeRounds.isEmpty else { return }
        currentOverallRound += 1
        totalRoundCount += 1
        currentRoundIndex = 0
        gamePhase = .playing
        // The extra pass is its own session: it is saved, restorable and
        // recorded in History like the first.
        let start = Date()
        gameStartDate = start
        lastRecordSaved = false
        sessionEvents = [.gameStarted(timestamp: start)]
        gameElapsedTime = 0
        startElapsedTimer()
        configureTimerForCurrentRound(autoStart: true)
    }

    // MARK: - Timer Configuration

    private func configureTimerForCurrentRound(autoStart: Bool) {
        let rounds = activeRounds
        guard currentRoundIndex < rounds.count else { return }

        let round = rounds[currentRoundIndex]
        currentRound = round

        sessionEvents.append(.roundStarted(playerName: round.name, emoji: round.emoji, timestamp: Date()))

        timerViewModel.reconfigureForRound(
            duration: round.durationSeconds,
            color: round.color.swiftUIColor
        )

        if autoStart && !round.startPaused {
            timerViewModel.play()
        }
        saveSession()
    }

    private func completeGame() {
        sessionStore?.clear()
        recordSessionEnd(saveRecord: true)
        timerViewModel.stopAndReset()
        timerViewModel.timerColorOverride = nil
        gamePhase = .gameOver
        currentRound = nil
    }

    private func resetSession(clearState: Bool, saveRecord: Bool) {
        if gamePhase != .idle { sessionStore?.clear() }
        recordSessionEnd(saveRecord: saveRecord)
        timerViewModel.stopAndReset()
        timerViewModel.timerColorOverride = nil
        gamePhase = .idle
        currentRoundIndex = 0
        currentOverallRound = 1
        currentRound = nil
        if clearState {
            gameSequence = nil
        }
    }

    private func recordSessionEnd(saveRecord: Bool) {
        guard gameStartDate != nil else { return }
        sessionEvents.append(.gameEnded(timestamp: Date()))
        stopElapsedTimer()
        if saveRecord {
            saveGameRecord()
        }
        gameStartDate = nil
    }

    /// User taps the play button on a paused-start round.
    func startCurrentRound() {
        guard gamePhase == .playing, timerViewModel.state == .notStarted else { return }
        timerViewModel.play()
        saveSession()
    }

    // MARK: - Session Recording

    func recordPause() {
        guard gamePhase == .playing else { return }
        sessionEvents.append(.paused(timestamp: Date()))
        stopElapsedTimer()
        saveSession()
    }

    func recordResume() {
        guard gamePhase == .playing else { return }
        sessionEvents.append(.resumed(timestamp: Date()))
        startElapsedTimer()
        saveSession()
    }

    // MARK: - Saving and Restoring

    /// Saves the playing session so it survives the app being closed.
    func saveSession() {
        resumeNote = nil
        guard let sessionStore, gamePhase == .playing, let game = gameSequence,
              let gameStartDate else { return }
        sessionStore.save(ActiveSessionSnapshot(
            game: game,
            currentRoundIndex: currentRoundIndex,
            currentOverallRound: currentOverallRound,
            totalRoundCount: totalRoundCount,
            sessionEvents: sessionEvents,
            gameStartDate: gameStartDate,
            timerTotalDuration: timerViewModel.totalDuration,
            timerProgress: timerViewModel.visualProgress,
            timerState: ActiveSessionSnapshot.TimerStateValue(timerViewModel.state),
            savedAt: Date()
        ))
    }

    /// Restores a session saved before the app was closed. Allowed only from
    /// `.idle`, so it never replaces a session in progress. A round that ran
    /// out while the app was closed finishes on the timer's next tick.
    /// A session saved longer ago than this comes back paused where it was
    /// saved, instead of replaying hours of overdue rounds.
    static let staleSessionAge: TimeInterval = 4 * 60 * 60

    @discardableResult
    func restoreSavedSession(now: Date = Date()) -> Bool {
        guard gamePhase == .idle, let snapshot = sessionStore?.load() else { return false }
        let rounds = snapshot.game.activeRounds
        guard rounds.indices.contains(snapshot.currentRoundIndex) else {
            sessionStore?.clear()
            return false
        }
        let round = rounds[snapshot.currentRoundIndex]
        gameSequence = snapshot.game
        currentRoundIndex = snapshot.currentRoundIndex
        currentOverallRound = snapshot.currentOverallRound
        totalRoundCount = snapshot.totalRoundCount
        sessionEvents = snapshot.sessionEvents
        gameStartDate = snapshot.gameStartDate
        currentRound = round
        gamePhase = .playing
        let savedAt = snapshot.savedAt ?? snapshot.gameStartDate
        let isStale = now.timeIntervalSince(savedAt) > Self.staleSessionAge
        var progress = snapshot.timerProgress
        var state = snapshot.timerState.timerState
        if isStale && state == .running {
            progress = progress.paused(at: savedAt)
            state = .paused
            sessionEvents.append(.paused(timestamp: savedAt))
        }
        timerViewModel.restore(
            totalDuration: snapshot.timerTotalDuration,
            progress: progress,
            state: state,
            color: round.color.swiftUIColor
        )
        if timerViewModel.state == .running {
            startElapsedTimer()
        }
        let place = "\(round.name), \(roundProgressText.lowercasedFirstWord)"
        resumeNote = isStale ? "You stopped at \(place)" : "Picked up where you left off: \(place)"
        return true
    }

    // MARK: - Elapsed Timer

    private func startElapsedTimer() {
        stopElapsedTimer()
        elapsedTimer = Timer
            .publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.gameElapsedTime += 1
            }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.cancel()
        elapsedTimer = nil
    }

    // MARK: - Controls

    func doOverToPrevious() {
        guard gamePhase == .playing, currentRoundIndex > 0 else { return }
        let rounds = activeRounds
        let prevIndex = currentRoundIndex - 1
        let prevPlayer = rounds[prevIndex]
        sessionEvents.append(.doOver(previousPlayer: prevPlayer.name, timestamp: Date()))
        currentRoundIndex = prevIndex
        configureTimerForCurrentRound(autoStart: true)
    }

    func skipCurrentRound() {
        guard gamePhase == .playing else { return }
        let rounds = activeRounds
        guard currentRoundIndex < rounds.count else { return }
        sessionEvents.append(.skipped(playerName: rounds[currentRoundIndex].name, timestamp: Date()))
        advanceToNextRound()
    }

    func restartCurrentTimer() {
        guard gamePhase == .playing else { return }
        if let round = currentRound {
            sessionEvents.append(.restartTimer(playerName: round.name, timestamp: Date()))
        }
        configureTimerForCurrentRound(autoStart: true)
    }

    /// Saves the completed game session to the History store.
    private func saveGameRecord() {
        guard let game = gameSequence else { return }
        let session = GameSession(events: sessionEvents)
        let record = GameRecord(
            id: UUID(),
            gameTitle: game.title,
            session: session,
            playerNames: activeRounds.map(\.name),
            playedAt: gameStartDate ?? Date(),
            roundColors: Dictionary(activeRounds.map { ($0.name, $0.color) }, uniquingKeysWith: { first, _ in first })
        )
        lastRecordSaved = historyStore.save(record)
        if lastRecordSaved {
            onHistoryRecordSaved?(record)
        }
    }
}

// MARK: - Active Session Persistence

/// Everything needed to put a playing session back on screen after the app was
/// closed. The countdown is wall-clock based, so restoring it is exact.
struct ActiveSessionSnapshot: Codable {
    enum TimerStateValue: String, Codable {
        case notStarted, running, paused

        init(_ state: TimerState) {
            switch state {
            case .running: self = .running
            case .paused: self = .paused
            case .notStarted, .finished: self = .notStarted
            }
        }

        var timerState: TimerState {
            switch self {
            case .notStarted: return .notStarted
            case .running: return .running
            case .paused: return .paused
            }
        }
    }

    var game: GameSequence
    var currentRoundIndex: Int
    var currentOverallRound: Int
    var totalRoundCount: Int
    var sessionEvents: [SessionEvent]
    var gameStartDate: Date
    var timerTotalDuration: Int
    var timerProgress: TimerVisualProgress
    var timerState: TimerStateValue
    /// When the snapshot was written; nil in snapshots from before this field.
    var savedAt: Date?
}

private extension String {
    /// "Step 4 of 8" → "step 4 of 8", for use mid-sentence.
    var lowercasedFirstWord: String {
        prefix(1).lowercased() + dropFirst()
    }
}

/// Stores at most one active session as a small JSON file. Malformed data is
/// discarded rather than restored.
struct ActiveSessionStore {
    private let url: URL

    init(directory: URL? = nil) {
        let base = directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("ActiveSession.json")
    }

    func save(_ snapshot: ActiveSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func load() -> ActiveSessionSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(ActiveSessionSnapshot.self, from: data) else {
            clear()
            return nil
        }
        return snapshot
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}

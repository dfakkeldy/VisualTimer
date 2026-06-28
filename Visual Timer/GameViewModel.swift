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

    /// The timer view model that does the actual countdown.
    let timerViewModel: TimerViewModel

    /// Plays the finish sound when rounds complete.
    weak var soundManager: SoundManager?

    private let historyStore: HistoryStore
    private let onHistoryRecordSaved: ((GameRecord) -> Void)?

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

    func loadGame(_ game: GameSequence) {
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
        totalRoundCount = game.roundCount
        gameStartDate = Date()
        gameElapsedTime = 0
        sessionEvents = []
        sessionEvents.append(.gameStarted(timestamp: gameStartDate!))
        startElapsedTimer()
        configureTimerForCurrentRound(autoStart: true)
    }

    func endGame(clearState: Bool = false) {
        sessionEvents.append(.gameEnded(timestamp: Date()))
        stopElapsedTimer()
        // Only persist a record if a game was actually played.
        if gameStartDate != nil {
            saveGameRecord()
        }
        gameStartDate = nil
        timerViewModel.pause()
        timerViewModel.reset()
        timerViewModel.timerColorOverride = nil
        gamePhase = .idle
        currentRoundIndex = 0
        currentOverallRound = 1
        currentRound = nil
        if clearState {
            gameSequence = nil
        }
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
            gamePhase = .gameOver
            currentRound = nil
            timerViewModel.timerColorOverride = nil
        }
    }

    /// Appends a new round during the game-over state.
    func addRoundDuringGameOver(_ round: Round) {
        guard gamePhase == .gameOver, var game = gameSequence else { return }
        var newRound = round
        newRound.orderIndex = game.rounds.count
        game.rounds.append(newRound)
        game.modifiedAt = Date()
        gameSequence = game

        currentRoundIndex = game.activeRounds.count - 1
        gamePhase = .playing
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
    }

    /// User taps the play button on a paused-start round.
    func startCurrentRound() {
        guard gamePhase == .playing, timerViewModel.state == .notStarted else { return }
        timerViewModel.play()
    }

    // MARK: - Session Recording

    func recordPause() {
        guard gamePhase == .playing else { return }
        sessionEvents.append(.paused(timestamp: Date()))
        stopElapsedTimer()
    }

    func recordResume() {
        guard gamePhase == .playing else { return }
        sessionEvents.append(.resumed(timestamp: Date()))
        startElapsedTimer()
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
            playedAt: gameStartDate ?? Date()
        )
        historyStore.save(record)
        onHistoryRecordSaved?(record)
    }
}

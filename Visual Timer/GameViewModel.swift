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

    /// The timer view model that does the actual countdown.
    let timerViewModel: TimerViewModel

    /// Plays the finish sound when rounds complete.
    weak var soundManager: SoundManager?

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

    // MARK: - Init

    init(timerViewModel: TimerViewModel, soundManager: SoundManager? = nil) {
        self.timerViewModel = timerViewModel
        self.soundManager = soundManager
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
        configureTimerForCurrentRound(autoStart: true)
    }

    func endGame(clearState: Bool = false) {
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
}

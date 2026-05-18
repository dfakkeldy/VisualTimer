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

    /// The timer view model that does the actual countdown.
    let timerViewModel: TimerViewModel

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

    init(timerViewModel: TimerViewModel) {
        self.timerViewModel = timerViewModel
    }

    // MARK: - Game Lifecycle

    func loadGame(_ game: GameSequence) {
        endGame(clearState: true)
        gameSequence = game
        currentRoundIndex = 0
        gamePhase = .ready
    }

    func startGame() {
        guard let game = gameSequence, gamePhase == .ready else { return }
        gamePhase = .playing
        currentRoundIndex = 0
        configureTimerForCurrentRound(autoStart: true)
    }

    func endGame(clearState: Bool = false) {
        timerViewModel.pause()
        timerViewModel.reset()
        timerViewModel.timerColorOverride = nil
        timerViewModel.onFinish = nil
        gamePhase = .idle
        currentRoundIndex = 0
        currentRound = nil
        if clearState {
            gameSequence = nil
        }
    }

    // MARK: - Round Advancement

    /// Called by `onFinish` when the current round's timer hits zero.
    private func advanceToNextRound() {
        let rounds = activeRounds
        let nextIndex = currentRoundIndex + 1

        if nextIndex < rounds.count {
            currentRoundIndex = nextIndex
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

        // Use the bypass method — the state-machine guard methods
        // (pause/reset) don't work from .finished, and onFinish fires
        // synchronously during handleTimerTick while state is .finished.
        timerViewModel.reconfigureForRound(
            duration: round.durationSeconds,
            color: round.color.swiftUIColor
        )

        // Wire the finish callback — advance to next round.
        timerViewModel.onFinish = { [weak self] in
            self?.advanceToNextRound()
        }

        if autoStart && !round.startPaused {
            timerViewModel.play()
        }
        // If startPaused, the timer stays in .notStarted — user taps to begin.
    }

    /// User taps the play button on a paused-start round.
    func startCurrentRound() {
        guard gamePhase == .playing, timerViewModel.state == .notStarted else { return }
        timerViewModel.play()
    }
}

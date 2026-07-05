import SwiftUI

/// Compact watchOS playback for a loaded `GameSequence`.
///
/// Mirrors the iOS `GamePlaybackView` conductor wiring: the timer's
/// `onFinish` plays the round-complete sound and advances the game via
/// `GameViewModel.handleTimerFinished()`. Launch contract is the same as
/// iOS — the caller runs `loadGame`/`startGame` before presenting this view.
struct WatchGamePlaybackView: View {

    @ObservedObject var gameViewModel: GameViewModel
    @ObservedObject var timerViewModel: TimerViewModel
    @ObservedObject var soundManager: SoundManager

    /// Dismissed back to the template browser when the user ends the game.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                if gameViewModel.gamePhase == .gameOver {
                    gameOverContent
                } else {
                    playingContent
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear { wireTimerFinish() }
        // Keep the conductor wired even if the view re-evaluates.
        .onChange(of: gameViewModel.gamePhase) { _ in wireTimerFinish() }
    }

    // MARK: - Playing

    @ViewBuilder
    private var playingContent: some View {
        if let round = gameViewModel.currentRound {
            Text("\(round.emoji.isEmpty ? "" : round.emoji + " ")\(round.name)")
                .font(.caption)
                .foregroundStyle(round.color.swiftUIColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }

        timerRing

        Text(timeText(timerViewModel.timeRemaining))
            .font(.system(.title2, design: .monospaced))
            .foregroundStyle(.primary)

        Text(gameViewModel.roundProgressText)
            .font(.caption2)
            .foregroundStyle(.secondary)

        controlRow
    }

    private var timerRing: some View {
        TimelineView(.animation(paused: !timerViewModel.visualProgress.isRunning)) { timeline in
            let elapsed = timerViewModel.visualProgress.elapsedFraction(at: timeline.date)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: elapsed, to: 1.0)
                    .stroke(timerViewModel.timerColor, lineWidth: 8)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 84, height: 84)
            .overlay {
                Image(systemName: playPauseIcon)
                    .font(.title3)
            }
            .onTapGesture { handleCircleTap() }
        }
    }

    private var controlRow: some View {
        HStack(spacing: 12) {
            Button {
                gameViewModel.doOverToPrevious()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(gameViewModel.currentRoundIndex == 0)

            Button {
                gameViewModel.skipCurrentRound()
            } label: {
                Image(systemName: "forward.fill")
            }
        }
        .font(.caption)
    }

    // MARK: - Game Over

    private var gameOverContent: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(.green)
            Text("Session Complete")
                .font(.caption)
            Button("Done") {
                gameViewModel.endGame()
                dismiss()
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Conductor

    private func wireTimerFinish() {
        timerViewModel.onFinish = { [weak soundManager, weak gameViewModel] in
            soundManager?.playFinishSound()
            gameViewModel?.handleTimerFinished()
        }
    }

    private func handleCircleTap() {
        switch timerViewModel.state {
        case .notStarted:
            if gameViewModel.gamePhase == .ready {
                gameViewModel.startGame()
            } else {
                gameViewModel.startCurrentRound()
            }
            timerViewModel.play()
        case .paused:
            gameViewModel.recordResume()
            timerViewModel.play()
        case .running:
            gameViewModel.recordPause()
            timerViewModel.pause()
        case .finished:
            break
        }
    }

    private var playPauseIcon: String {
        switch timerViewModel.state {
        case .notStarted, .paused, .finished: return "play.fill"
        case .running: return "pause.fill"
        }
    }

    private func timeText(_ seconds: Int) -> String {
        let m = max(0, seconds) / 60
        let s = max(0, seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

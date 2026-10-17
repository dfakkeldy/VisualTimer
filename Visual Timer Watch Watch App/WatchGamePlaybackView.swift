import SwiftUI

/// Compact watchOS playback for a loaded `GameSequence`.
///
/// `WatchAppModel` owns the session, its completion alerts and the conductor
/// wiring (`onFinish` → alert → `GameViewModel.handleTimerFinished()`), so the
/// session keeps running when this screen is dismissed. This view renders
/// state and forwards control taps.
struct WatchGamePlaybackView: View {

    @ObservedObject var gameViewModel: GameViewModel
    @ObservedObject var timerViewModel: TimerViewModel

    let onPrimary: () -> Void
    let onRestart: () -> Void
    let onPrevious: () -> Void
    let onSkip: () -> Void
    let onEnd: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Watch.Dimension.contentSpacing) {
                if gameViewModel.gamePhase == .gameOver {
                    gameOverContent
                } else {
                    playingContent
                }
            }
        }
        .navigationTitle(gameViewModel.gameSequence?.title ?? "")
    }

    // MARK: - Playing

    @ViewBuilder
    private var playingContent: some View {
        if let round = gameViewModel.currentRound {
            Text("\(round.emoji.isEmpty ? "" : round.emoji + " ")\(round.name)")
                .font(.headline)
                .foregroundStyle(round.color.swiftUIColor)
                .lineLimit(1)
                .minimumScaleFactor(Theme.Watch.Dimension.captionMinimumScale)
        }

        WatchTimerDial(
            progress: timerViewModel.visualProgress,
            color: timerViewModel.timerColor
        ) { date in
            remainingTime(at: date)
        }
        .frame(
            width: Theme.Watch.Dimension.sessionDialSize,
            height: Theme.Watch.Dimension.sessionDialSize
        )

        HStack(spacing: Theme.Watch.Dimension.controlSpacing) {
            if let primary = WatchPrimaryControl(state: timerViewModel.state) {
                WatchControlButton(
                    title: primary.title,
                    systemImage: primary.symbol,
                    accessibilityID: Theme.Watch.Identifier.sessionPrimary,
                    isProminent: true,
                    action: onPrimary
                )
            }
            WatchControlButton(
                title: Theme.Label.restart,
                systemImage: Theme.Symbol.reset,
                accessibilityID: Theme.Watch.Identifier.sessionRestart,
                isProminent: false,
                action: onRestart
            )
        }

        Text(gameViewModel.roundProgressText)
            .font(.caption2)
            .foregroundStyle(.secondary)

        HStack(spacing: Theme.Watch.Dimension.controlSpacing) {
            WatchControlButton(
                title: Theme.Watch.Label.previous,
                systemImage: Theme.Watch.Symbol.previous,
                accessibilityID: Theme.Watch.Identifier.sessionPrevious,
                isProminent: false,
                action: onPrevious
            )
            .disabled(gameViewModel.currentRoundIndex == 0)

            WatchControlButton(
                title: Theme.Label.skip,
                systemImage: Theme.Symbol.skip,
                accessibilityID: Theme.Watch.Identifier.sessionSkip,
                isProminent: false,
                action: onSkip
            )
        }

        WatchControlButton(
            title: Theme.Label.endGame,
            systemImage: Theme.Symbol.endGame,
            accessibilityID: Theme.Watch.Identifier.sessionEnd,
            isProminent: false
        ) {
            onEnd()
            dismiss()
        }
    }

    private func remainingTime(at date: Date) -> some View {
        let seconds = timerViewModel.visualProgress.remainingSeconds(at: date)
        return Text(WatchTimeText.clock(seconds))
            .font(.system(.title3, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(Theme.Watch.Dimension.digitMinimumScale)
            .accessibilityLabel(Theme.Watch.Label.timeRemaining)
            .accessibilityValue(WatchTimeText.spoken(seconds))
            .accessibilityIdentifier(Theme.Watch.Identifier.sessionTime)
    }

    // MARK: - Session Complete

    private var gameOverContent: some View {
        VStack(spacing: Theme.Watch.Dimension.contentSpacing) {
            Image(systemName: Theme.Watch.Symbol.sessionComplete)
                .font(.title)
                .foregroundStyle(Theme.Watch.ColorValue.sessionComplete)
                .accessibilityHidden(true)
            Text(Theme.Watch.Label.sessionComplete)
                .font(.headline)
            WatchControlButton(
                title: Theme.Watch.Label.done,
                systemImage: Theme.Symbol.checkmark,
                accessibilityID: Theme.Watch.Identifier.sessionDone,
                isProminent: true
            ) {
                onEnd()
                dismiss()
            }
        }
    }
}

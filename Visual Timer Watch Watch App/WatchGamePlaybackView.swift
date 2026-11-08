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
    @State private var confirmEnd = false

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
        .confirmationDialog("End this session?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End and save", role: .destructive) {
                onEnd()
                dismiss()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("What you've done so far is saved to History.")
        }
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
            color: timerViewModel.timerColor,
            dialSize: Theme.Watch.Dimension.sessionDialSize,
            centerSymbol: WatchPrimaryControl(state: timerViewModel.state)?.symbol,
            onTap: onPrimary
        ) { date in
            remainingTime(at: date)
        }

        if let next = gameViewModel.nextRound {
            Text("Next: \(next.emoji.isEmpty ? "" : next.emoji + " ")\(next.name)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(next.color.swiftUIColor)
                .lineLimit(1)
        }
        Text("\(gameViewModel.roundProgressText) · \(sessionLeftText) left")
            .font(.caption2)
            .foregroundStyle(.secondary)

        HStack(spacing: Theme.Watch.Dimension.controlSpacing) {
            if let primary = WatchPrimaryControl(state: timerViewModel.state) {
                WatchControlButton(
                    title: primary.title,
                    systemImage: primary.symbol,
                    accessibilityID: Theme.Watch.Identifier.sessionPrimary,
                    isProminent: true,
                    tint: timerViewModel.timerColor,
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
            confirmEnd = true
        }
    }

    private var sessionLeftText: String {
        let seconds = gameViewModel.remainingSessionSeconds(currentRemaining: timerViewModel.timeRemaining)
        return seconds < 60 ? "under a minute" : "\(Int((Double(seconds) / 60).rounded())) min"
    }

    private func remainingTime(at date: Date) -> some View {
        let seconds = timerViewModel.visualProgress.remainingSeconds(at: date)
        return Text(WatchTimeText.clock(seconds))
            .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
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
                .foregroundStyle(gameViewModel.activeRounds.last?.color.swiftUIColor ?? Theme.Watch.ColorValue.sessionComplete)
                .accessibilityHidden(true)
            Text(Theme.Watch.Label.sessionComplete)
                .font(.headline)
            Text("Total \(WatchTimeText.clock(Int(gameViewModel.sessionDurationSeconds))) · saved")
                .font(.caption2)
                .foregroundStyle(.secondary)
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

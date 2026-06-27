import SwiftUI

struct GamePlaybackView: View {

    @ObservedObject var timerViewModel: TimerViewModel
    @ObservedObject var gameViewModel: GameViewModel
    @ObservedObject var soundManager: SoundManager
    @ObservedObject var proAccess: ProAccessViewModel
    @ObservedObject var templateSync: TemplateCloudSyncEngine

    @State private var showSettings = false

    var body: some View {
        ZStack {
            Theme.ColorValue.appBackground.ignoresSafeArea()

            if gameViewModel.hasActiveGame {
                gamePlaybackContent
            } else {
                quickTimerContent
            }

            // Settings gear — only in quick timer mode
            if !gameViewModel.hasActiveGame {
                settingsGear
            }
        }
        .animation(
            .easeInOut(duration: Theme.AnimationValue.stateTransitionDuration),
            value: timerViewModel.state
        )
        .animation(
            .easeInOut(duration: Theme.AnimationValue.stateTransitionDuration),
            value: gameViewModel.gamePhase
        )
        .sheet(isPresented: $showSettings) {
            SettingsView(
                soundManager: soundManager,
                proAccess: proAccess,
                templateSync: templateSync
            )
        }
        .onAppear {
            timerViewModel.onFinish = { [weak soundManager, weak gameViewModel] in
                soundManager?.playFinishSound()
                gameViewModel?.handleTimerFinished()
            }
        }
    }

    // MARK: - Quick Timer (existing behavior)

    private var quickTimerContent: some View {
        VStack(spacing: 0) {
            durationStepper

            Spacer()

            timerCircleButton

            TimeDisplayView(timeRemaining: timerViewModel.timeRemaining)
                .padding(.top, Theme.Dimension.sectionSpacingSmall)

            Spacer()

            resetButton
                .padding(.bottom, Theme.Dimension.sectionSpacingLarge)
        }
        .padding(.horizontal, Theme.Dimension.screenHorizontalPadding)
    }

    // MARK: - Game Playback

    private var gamePlaybackContent: some View {
        VStack(spacing: Theme.GamePlayback.playbackSpacing) {

            if gameViewModel.gamePhase == .gameOver {
                gameOverView
            } else {
                roundInfoHeader
            }

            // Game duration counter
            if gameViewModel.gamePhase != .ready {
                Text(formatElapsed(gameViewModel.gameElapsedTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                    .padding(.top, 4)
            }

            Spacer()

            timerCircleButton

            TimeDisplayView(timeRemaining: timerViewModel.timeRemaining)
                .padding(.top, Theme.Dimension.sectionSpacingSmall)

            // Control buttons
            if gameViewModel.gamePhase == .playing {
                HStack(spacing: 24) {
                    Button {
                        gameViewModel.doOverToPrevious()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: Theme.Symbol.doOver)
                                .font(.title3)
                            Text(Theme.Label.doOver)
                                .font(.caption2)
                        }
                        .foregroundStyle(Theme.ColorValue.textSecondary)
                    }
                    .disabled(gameViewModel.currentRoundIndex == 0)

                    Button {
                        gameViewModel.skipCurrentRound()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: Theme.Symbol.skip)
                                .font(.title3)
                            Text(Theme.Label.skip)
                                .font(.caption2)
                        }
                        .foregroundStyle(Theme.ColorValue.textSecondary)
                    }

                    Button {
                        gameViewModel.restartCurrentTimer()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: Theme.Symbol.restart)
                                .font(.title3)
                            Text(Theme.Label.restart)
                                .font(.caption2)
                        }
                        .foregroundStyle(Theme.ColorValue.textSecondary)
                    }
                }
                .padding(.top, 12)
            }

            Spacer()

            if gameViewModel.gamePhase == .playing {
                roundProgressFooter
            }

            if gameViewModel.gamePhase == .gameOver {
                gameOverActions
            }
        }
        .padding(.horizontal, Theme.Dimension.screenHorizontalPadding)
        .padding(.bottom, Theme.Dimension.sectionSpacingLarge)
    }

    // MARK: - Round Info Header

    private var roundInfoHeader: some View {
        HStack {
            // Current player (left)
            if let round = gameViewModel.currentRound {
                HStack(spacing: 4) {
                    if !round.emoji.isEmpty {
                        Text(round.emoji)
                            .font(.system(size: 56))
                    }
                    Text(round.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(round.color.swiftUIColor)
                }
            }

            Spacer()

            // Next player indicator (right)
            if let next = gameViewModel.nextPlayer {
                HStack(spacing: 4) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Theme.Label.nextPlayer)
                            .font(.caption2)
                            .foregroundStyle(Theme.ColorValue.textSecondary)
                        HStack(spacing: 4) {
                            if !next.emoji.isEmpty {
                                Text(next.emoji)
                            }
                            Text(next.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.ColorValue.textSecondary)
                        }
                    }
                    Image(systemName: Theme.Symbol.nextPlayer)
                        .font(.caption)
                        .foregroundStyle(Theme.ColorValue.textSecondary)
                }
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Round Progress Footer

    private var roundProgressFooter: some View {
        VStack(spacing: 4) {
            Text("Turn \(gameViewModel.countingPlayerIndex) of \(gameViewModel.countingPlayerCount)")
                .font(.system(size: Theme.GamePlayback.roundProgressFontSize))
                .foregroundStyle(Theme.ColorValue.textSecondary)

            if gameViewModel.totalRoundCount > 1 {
                Text("Sequence \(gameViewModel.currentOverallRound) of \(gameViewModel.totalRoundCount)")
                    .font(.system(size: Theme.GamePlayback.roundProgressFontSize))
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }
        }
    }

    // MARK: - Session Complete

    private var gameOverView: some View {
        VStack(spacing: 8) {
            Text("Session Complete")
                .font(.system(
                    size: Theme.GamePlayback.gameOverFontSize,
                    weight: .bold
                ))
                .foregroundStyle(Theme.ColorValue.textPrimary)
                .padding(.top, 16)
        }
    }

    private var gameOverActions: some View {
        HStack(spacing: Theme.Dimension.controlButtonSpacing) {
            Button {
                let timeout = Round(
                    name: "Extra Round",
                    durationSeconds: Theme.TimerMechanic.defaultDuration,
                    orderIndex: gameViewModel.activeRounds.count
                )
                gameViewModel.addRoundDuringGameOver(timeout)
            } label: {
                Label("Add Round", systemImage: Theme.Symbol.increment)
                    .font(.body.weight(.medium))
            }

            Button {
                gameViewModel.endGame()
            } label: {
                Label(Theme.Label.endGame, systemImage: Theme.Symbol.endGame)
                    .font(.body.weight(.medium))
            }
        }
    }

    // MARK: - Shared Sub-Views

    private var timerCircleButton: some View {
        ZStack {
            TimerVisualView(
                elapsedFraction: elapsedFraction,
                fillColor: timerViewModel.timerColor
            )

            if let icon = centerIcon {
                Image(systemName: icon)
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .contentShape(Circle())
        .onTapGesture { handleCircleTap() }
    }

    private var centerIcon: String? {
        switch timerViewModel.state {
        case .notStarted, .paused, .finished:
            return Theme.Symbol.play
        case .running:
            return Theme.Symbol.pause
        }
    }

    private func handleCircleTap() {
        let wasPaused = timerViewModel.state == .paused

        switch timerViewModel.state {
        case .notStarted, .paused:
            if gameViewModel.hasActiveGame && timerViewModel.state == .notStarted {
                gameViewModel.startCurrentRound()
            } else {
                timerViewModel.play()
            }
            if gameViewModel.hasActiveGame && wasPaused {
                gameViewModel.recordResume()
            }
        case .running:
            timerViewModel.pause()
            if gameViewModel.hasActiveGame {
                gameViewModel.recordPause()
            }
        case .finished:
            break
        }
    }

    private var elapsedFraction: Double {
        guard timerViewModel.totalDuration > 0 else { return 0 }
        let notch = timerViewModel.state == .notStarted ? 0 : 1
        let raw = Double(timerViewModel.totalDuration - timerViewModel.timeRemaining + notch)
            / Double(timerViewModel.totalDuration)
        return min(raw, 1.0)
    }

    // MARK: - Quick Timer Sub-Views

    private var durationStepper: some View {
        HStack(spacing: Theme.Dimension.durationStepperSpacing) {
            Button {
                timerViewModel.setDuration(
                    max(Theme.TimerMechanic.minimumDuration,
                        timerViewModel.totalDuration - Theme.TimerMechanic.durationStep)
                )
            } label: {
                Image(systemName: Theme.Symbol.decrement)
                    .font(.title3)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }
            .disabled(timerViewModel.state != .notStarted)
            .accessibilityLabel(Theme.Label.decrementDuration)

            Text("\(timerViewModel.totalDuration / 60)m \(timerViewModel.totalDuration % 60)s")
                .font(.title3.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Theme.ColorValue.textPrimary)

            Button {
                timerViewModel.setDuration(
                    timerViewModel.totalDuration + Theme.TimerMechanic.durationStep
                )
            } label: {
                Image(systemName: Theme.Symbol.increment)
                    .font(.title3)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }
            .disabled(timerViewModel.state != .notStarted)
            .accessibilityLabel(Theme.Label.incrementDuration)
        }
    }

    private var resetButton: some View {
        HStack {
            Spacer()
            Button {
                timerViewModel.reset()
            } label: {
                Circle()
                    .fill(Theme.ColorValue.buttonFill)
                    .frame(
                        width: Theme.Dimension.controlButtonSize,
                        height: Theme.Dimension.controlButtonSize
                    )
                    .overlay {
                        Image(systemName: Theme.Symbol.reset)
                            .font(.title2.weight(.medium))
                            .foregroundStyle(Theme.ColorValue.textPrimary)
                    }
            }
            .disabled(timerViewModel.state != .paused)
            .accessibilityLabel(Theme.Label.reset)
        }
    }

    // MARK: - Helpers

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private var settingsGear: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: Theme.Symbol.settings)
                        .font(.title3)
                        .foregroundStyle(Theme.ColorValue.textSecondary)
                }
                .accessibilityLabel(Theme.Label.settings)
            }
            .padding(.horizontal, Theme.Dimension.screenHorizontalPadding)
            .padding(.top, Theme.Dimension.gearTopPadding)

            Spacer()
        }
    }
}

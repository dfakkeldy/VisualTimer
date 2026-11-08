import SwiftUI

/// The Timer tab: the quick timer, or the running session when one is active.
///
/// Everything sits on one vertical axis: a top row (settings, or the session
/// header with End), the dial (which is the play/pause control), the digits
/// with one plain caption, one control row, and the session's progress.
struct GamePlaybackView: View {

    @ObservedObject var timerViewModel: TimerViewModel
    @ObservedObject var gameViewModel: GameViewModel
    @ObservedObject var soundManager: SoundManager
    @ObservedObject var proAccess: ProAccessViewModel
    @ObservedObject var templateSync: TemplateCloudSyncEngine
    @ObservedObject var historySync: HistoryCloudSyncEngine
    var onTimerStateChange: () -> Void = {}

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showSettings = false
    @State private var confirmEnd = false
    @AppStorage(TimerAlertScheduler.enabledKey) private var alertsEnabled = false
    @AppStorage("timerAlertsOffered") private var alertsOffered = false

    var body: some View {
        ZStack {
            TimerBackdrop(color: backdropColor)

            Group {
                if verticalSizeClass == .compact {
                    landscapeContent
                } else {
                    portraitContent
                }
            }
            .padding(.horizontal, Theme.Dimension.screenHorizontalPadding)
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: Theme.AnimationValue.stateTransitionDuration),
            value: timerViewModel.state
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: Theme.AnimationValue.stateTransitionDuration),
            value: gameViewModel.gamePhase
        )
        .sheet(isPresented: $showSettings) {
            SettingsView(
                soundManager: soundManager,
                proAccess: proAccess,
                templateSync: templateSync,
                historySync: historySync
            )
        }
        .confirmationDialog("End this session?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End and save to History", role: .destructive) {
                gameViewModel.endGame()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("What you've done so far is saved to History.")
        }
        .onChange(of: timerViewModel.state) { _, _ in
            onTimerStateChange()
        }
        .onChange(of: timerViewModel.visualProgress) { _, progress in
            scheduleEndAlert(progress)
        }
        .onAppear {
            timerViewModel.onFinish = { [weak soundManager, weak gameViewModel] in
                soundManager?.playFinishSound()
                gameViewModel?.handleTimerFinished()
            }
        }
    }

    private var isComplete: Bool { gameViewModel.gamePhase == .gameOver }

    /// One pending alert for the running countdown's end; none otherwise.
    private func scheduleEndAlert(_ progress: TimerVisualProgress) {
        if inSession, let round = gameViewModel.currentRound {
            let name = round.emoji.isEmpty ? round.name : "\(round.emoji) \(round.name)"
            let next = gameViewModel.nextRound.map { "Next: \($0.name)" } ?? "That was the last one."
            TimerAlertScheduler.update(finishDate: progress.finishDate, title: "\(name) is done", body: next)
        } else {
            TimerAlertScheduler.update(finishDate: progress.finishDate, title: "Time's up", body: "Your \(TimerText.words(timerViewModel.totalDuration)) timer has finished.")
        }
    }
    private var inSession: Bool { gameViewModel.hasActiveGame }

    private var backdropColor: Color {
        if isComplete, let first = gameViewModel.activeRounds.first {
            return first.color.swiftUIColor
        }
        return timerViewModel.timerColor
    }

    // MARK: - Layouts

    private var portraitContent: some View {
        VStack(spacing: 0) {
            topRow
                .padding(.top, Theme.Dimension.gearTopPadding)

            Spacer(minLength: Theme.Dimension.sectionSpacingSmall)

            dial
                .frame(maxWidth: Theme.GamePlayback.dialMaxSize)
                .layoutPriority(1)
                // The quick timer has no footer; centre its group optically.
                .padding(.top, inSession ? 0 : Theme.Dimension.sectionSpacingLarge)

            readout
                .padding(.top, Theme.Dimension.sectionSpacingSmall)

            controlRow
                .padding(.top, Theme.Dimension.sectionSpacingSmall)

            if showsAlertOffer {
                alertOffer
                    .padding(.top, Theme.Dimension.sectionSpacingSmall)
            }

            Spacer(minLength: Theme.Dimension.sectionSpacingSmall)

            progressFooter
                .padding(.bottom, Theme.Dimension.sectionSpacingSmall)
        }
    }

    private var landscapeContent: some View {
        HStack(spacing: Theme.Dimension.sectionSpacingLarge) {
            dial
                .frame(maxWidth: Theme.Dimension.landscapeTimerCircleMaxSize)
            VStack(spacing: Theme.Dimension.sectionSpacingSmall) {
                topRow
                readout
                controlRow
                progressFooter
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Theme.Dimension.compactContentVerticalPadding)
    }

    // MARK: - Top row

    @ViewBuilder
    private var topRow: some View {
        if isComplete {
            completeHeader
        } else if inSession {
            sessionHeader
        } else {
            HStack {
                Spacer()
                GlassIconButton(systemImage: Theme.Symbol.settings, label: Theme.Label.settings, size: 36) {
                    showSettings = true
                }
            }
        }
    }

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                if let title = gameViewModel.gameSequence?.title {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.ColorValue.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                GlassCapsuleButton(title: Theme.Label.endShort, systemImage: Theme.Symbol.stopSession) {
                    confirmEnd = true
                }
                .accessibilityLabel(Theme.Label.endGame)
            }

            HStack(alignment: .lastTextBaseline, spacing: Theme.Dimension.durationStepperSpacing) {
                if let round = gameViewModel.currentRound {
                    HStack(alignment: .center, spacing: 8) {
                        if !round.emoji.isEmpty {
                            Text(round.emoji)
                                .font(.system(size: Theme.GamePlayback.headerEmojiSize))
                                .accessibilityHidden(true)
                        }
                        Text(round.name)
                            .font(.system(size: Theme.GamePlayback.headerNameSize, weight: .bold))
                            .foregroundStyle(round.color.swiftUIColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Now: \(round.name)")
                }

                Spacer(minLength: 8)

                if let next = gameViewModel.nextRound {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Theme.Label.nextPlayer)
                            .font(.caption)
                            .foregroundStyle(Theme.ColorValue.textTertiary)
                        HStack(spacing: 5) {
                            if next.emoji.isEmpty {
                                Circle()
                                    .fill(next.color.swiftUIColor)
                                    .frame(width: 8, height: 8)
                            }
                            Text(next.emoji.isEmpty ? next.name : "\(next.emoji) \(next.name)")
                                .font(.body.weight(.medium))
                                .foregroundStyle(next.color.swiftUIColor.opacity(0.9))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    .frame(maxWidth: Theme.GamePlayback.nextPlayerMaxWidth, alignment: .trailing)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Next: \(next.name)")
                }
            }
        }
    }

    private var completeHeader: some View {
        VStack(spacing: 6) {
            Text("All done")
                .font(.system(size: Theme.GamePlayback.gameOverFontSize, weight: .bold))
                .foregroundStyle(Theme.ColorValue.textPrimary)
            Text(completionLine)
                .font(.subheadline)
                .foregroundStyle(Theme.ColorValue.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Dimension.sectionSpacingSmall)
        .accessibilityElement(children: .combine)
    }

    /// Counts, not verdicts, and "saved" only once the record was written.
    private var completionLine: String {
        let skipped = gameViewModel.skippedCount
        let done: String
        if skipped > 0 {
            done = "\(skipped) skipped"
        } else {
            done = gameViewModel.countingPlayerCount > 0 ? "Everyone had a turn" : "Every step done"
        }
        let receipt = gameViewModel.lastRecordSaved ? "saved to History" : "couldn't save to History"
        return "\(done) · \(receipt)"
    }

    // MARK: - Dial

    @ViewBuilder
    private var dial: some View {
        if isComplete, let game = gameViewModel.gameSequence {
            ZStack {
                SequencePie(segments: game.segments, glowColor: .white.opacity(0.6))
                GlyphDisc {
                    Image(systemName: Theme.Symbol.checkmark)
                        .font(.system(size: Theme.TimerStyle.runningIconSize, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, Theme.Dimension.circleHorizontalPadding)
            .accessibilityElement()
            .accessibilityLabel(Theme.Label.gameOver)
        } else {
            timerCircleButton
        }
    }

    private var timerCircleButton: some View {
        Button {
            handleCircleTap()
        } label: {
            ZStack {
                TimerVisualView(
                    visualProgress: timerViewModel.visualProgress,
                    fillColor: timerViewModel.timerColor,
                    completionCount: timerViewModel.timerColorIndex
                )
                // Paused reads from across the room: the colour dims along a
                // clean path (less saturation and light), not toward grey-pink.
                .saturation(timerViewModel.state == .paused ? 0.7 : 1)
                .brightness(timerViewModel.state == .paused ? -0.18 : 0)

                if let icon = centerIcon {
                    GlyphDisc {
                        Image(systemName: icon)
                            .font(.system(size: Theme.TimerStyle.runningIconSize, weight: .semibold))
                            .foregroundStyle(.white.opacity(Theme.TimerStyle.iconOpacity))
                            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                    }
                    .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(TimerPressStyle())
        .contentShape(Circle())
        .disabled(!isTimerCircleEnabled)
        .accessibilityLabel(timerCircleAccessibilityLabel)
    }

    private var centerIcon: String? {
        guard isTimerCircleEnabled else { return nil }
        switch timerViewModel.state {
        case .notStarted, .paused, .finished:
            return Theme.Symbol.play
        case .running:
            return Theme.Symbol.pause
        }
    }

    private var isTimerCircleEnabled: Bool {
        if gameViewModel.gamePhase == .ready || gameViewModel.gamePhase == .gameOver {
            return false
        }
        return timerViewModel.state != .finished
    }

    private var timerCircleAccessibilityLabel: String {
        switch timerViewModel.state {
        case .running:
            return Theme.Label.pause
        case .paused:
            return Theme.Label.unpause
        case .notStarted:
            return Theme.Label.play
        case .finished:
            return Theme.Label.gameOver
        }
    }

    private func handleCircleTap() {
        guard isTimerCircleEnabled else { return }
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
            if gameViewModel.hasActiveGame && timerViewModel.state == .paused {
                gameViewModel.recordPause()
            }
        case .finished:
            break
        }
    }

    // MARK: - Readout: digits and one caption

    private var readout: some View {
        VStack(spacing: Theme.TimerStyle.captionSpacing) {
            HStack(spacing: Theme.Dimension.durationStepperSpacing) {
                if showsDurationControls {
                    GlassIconButton(systemImage: Theme.Symbol.decrease, label: Theme.Label.decrementDuration) {
                        timerViewModel.setDuration(
                            max(Theme.TimerMechanic.minimumDuration,
                                timerViewModel.totalDuration - Theme.TimerMechanic.durationStep)
                        )
                    }
                    .disabled(timerViewModel.totalDuration <= Theme.TimerMechanic.minimumDuration)
                }

                if isComplete {
                    Text(TimerText.length(Int(gameViewModel.sessionDurationSeconds)))
                        .font(.system(size: Theme.TimerStyle.digitsSize, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ColorValue.textPrimary)
                        .accessibilityLabel("Total time \(TimerText.words(Int(gameViewModel.sessionDurationSeconds)))")
                } else {
                    TimeDisplayView(timeRemaining: timerViewModel.timeRemaining)
                }

                if showsDurationControls {
                    GlassIconButton(systemImage: Theme.Symbol.increase, label: Theme.Label.incrementDuration) {
                        timerViewModel.setDuration(timerViewModel.totalDuration + Theme.TimerMechanic.durationStep)
                    }
                }
            }

            Text(caption)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Theme.ColorValue.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier("timer.caption")
        }
    }

    /// −/+ belong to the quick timer and only while it can be changed.
    private var showsDurationControls: Bool {
        !inSession && timerViewModel.state == .notStarted
    }

    private var caption: String {
        if let note = gameViewModel.resumeNote, inSession, !isComplete {
            return note
        }
        if isComplete {
            let steps = gameViewModel.activeRounds.count * max(gameViewModel.totalRoundCount, 1)
            let noun = gameViewModel.countingPlayerCount > 0 ? "turn" : "step"
            return "Total time · \(TurnTimerCountText.label(for: steps, singular: noun))"
        }
        let remaining = timerViewModel.timeRemaining
        if inSession {
            let sessionLeft = gameViewModel.remainingSessionSeconds(currentRemaining: remaining)
            switch timerViewModel.state {
            case .running:
                return "Session · \(TimerText.left(sessionLeft)) · \(TimerText.endsAt(sessionLeft).lowercasedFirst)"
            case .paused:
                return "\(Theme.Label.paused) · tap the dial to resume"
            case .notStarted, .finished:
                return Theme.Label.tapToStart
            }
        }
        switch timerViewModel.state {
        case .running:
            return TimerText.endsAt(remaining)
        case .paused:
            return "\(Theme.Label.paused) · tap the dial to resume"
        case .notStarted, .finished:
            return Theme.Label.tapToStart
        }
    }

    // MARK: - Control row

    @ViewBuilder
    private var controlRow: some View {
        Group {
            if isComplete {
                HStack(spacing: Theme.TimerStyle.controlSpacing * 2) {
                    GlassCapsuleButton(title: Theme.Label.goAgain, systemImage: Theme.Symbol.restart, fillsWidth: true) {
                        gameViewModel.addRoundDuringGameOver()
                    }
                    GlassCapsuleButton(title: Theme.Label.done, systemImage: nil, prominent: true, fillsWidth: true) {
                        gameViewModel.endGame()
                    }
                }
            } else if inSession {
                TimerGlassGroup {
                    HStack(spacing: Theme.TimerStyle.controlSpacing) {
                        GlassCapsuleButton(title: Theme.Label.doOver, systemImage: Theme.Symbol.doOver, fillsWidth: true) {
                            gameViewModel.doOverToPrevious()
                        }
                        .disabled(gameViewModel.currentRoundIndex == 0)
                        GlassCapsuleButton(title: Theme.Label.restart, systemImage: Theme.Symbol.restart, fillsWidth: true) {
                            gameViewModel.restartCurrentTimer()
                        }
                        GlassCapsuleButton(title: Theme.Label.skip, systemImage: Theme.Symbol.skip, fillsWidth: true) {
                            gameViewModel.skipCurrentRound()
                        }
                    }
                }
            } else if timerViewModel.state == .paused {
                GlassCapsuleButton(title: Theme.Label.reset, systemImage: Theme.Symbol.reset) {
                    timerViewModel.reset()
                }
                .accessibilityLabel(Theme.Label.reset)
            } else {
                Color.clear
            }
        }
        .frame(minHeight: Theme.TimerStyle.capsuleHeight)
    }

    // MARK: - Alert offer

    /// Offered once, while a timer runs, because that is when an alert
    /// would help: the hook by the door, with a plain "Not now".
    private var showsAlertOffer: Bool {
        !alertsEnabled && !alertsOffered && timerViewModel.state == .running
    }

    private var alertOffer: some View {
        HStack(spacing: 10) {
            Image(systemName: "bell")
                .foregroundStyle(Theme.ColorValue.textSecondary)
                .accessibilityHidden(true)
            Text("Alert me when time's up, even outside the app?")
                .font(.footnote)
                .foregroundStyle(Theme.ColorValue.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("Turn on") {
                alertsOffered = true
                Task {
                    alertsEnabled = await TimerAlertScheduler.requestPermission()
                    scheduleEndAlert(timerViewModel.visualProgress)
                }
            }
            .font(.footnote.weight(.semibold))
            Button("Not now") {
                alertsOffered = true
            }
            .font(.footnote)
            .foregroundStyle(Theme.ColorValue.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.ColorValue.surface, in: .rect(cornerRadius: 14))
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressFooter: some View {
        if inSession && !isComplete {
            VStack(spacing: 8) {
                progressDots
                Text(progressText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(progressText)
        } else {
            Color.clear.frame(height: 1)
        }
    }

    private var progressText: String {
        var text = gameViewModel.roundProgressText
        if gameViewModel.totalRoundCount > 1 {
            text += " · Repeat \(gameViewModel.currentOverallRound) of \(gameViewModel.totalRoundCount)"
        }
        return text
    }

    /// One dot per round in this pass, in its colour: done rounds filled,
    /// the current one larger, later ones as outlines.
    private var progressDots: some View {
        HStack(spacing: Theme.GamePlayback.progressDotSpacing) {
            ForEach(Array(gameViewModel.activeRounds.enumerated()), id: \.offset) { index, round in
                let color = round.color.swiftUIColor
                let isCurrent = index == gameViewModel.currentRoundIndex
                let size = isCurrent ? Theme.GamePlayback.progressDotCurrentSize : Theme.GamePlayback.progressDotSize
                // In a turn-based session, breaks are short bars so the dots
                // count the same turns as the text beneath them.
                let isBreak = gameViewModel.countingPlayerCount > 0 && !round.countsAsPlayer
                let shape = Capsule()
                Group {
                    if index <= gameViewModel.currentRoundIndex {
                        shape.fill(color)
                    } else {
                        shape.strokeBorder(color.opacity(0.7), lineWidth: 1.5)
                    }
                }
                .frame(width: isBreak ? size * 1.8 : size, height: isBreak ? 3 : size)
            }
        }
    }
}

private extension String {
    var lowercasedFirst: String {
        prefix(1).lowercased() + dropFirst()
    }
}

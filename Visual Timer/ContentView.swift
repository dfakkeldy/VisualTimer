import SwiftUI

/// Root view that composes the timer sub-views, wires the ViewModel
/// and SoundManager together, and presents the settings sheet.
///
/// The timer circle itself is the Play/Pause button. The Reset button
/// appears bottom-right when paused. The duration stepper sits at the top.
struct ContentView: View {

    @StateObject private var viewModel = TimerViewModel()
    @StateObject private var soundManager = SoundManager()

    @State private var showSettings = false

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.ColorValue.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                durationStepper
                    .opacity(viewModel.state == .notStarted ? 1 : 0)

                Spacer()

                timerCircleButton

                TimeDisplayView(timeRemaining: viewModel.timeRemaining)
                    .padding(.top, Theme.Dimension.sectionSpacingSmall)

                Spacer()

                resetButton
                    .padding(.bottom, Theme.Dimension.sectionSpacingLarge)
            }
            .padding(.horizontal, Theme.Dimension.screenHorizontalPadding)

            settingsGear
        }
        .animation(
            .easeInOut(duration: Theme.AnimationValue.stateTransitionDuration),
            value: viewModel.state
        )
        .sheet(isPresented: $showSettings) {
            SettingsView(soundManager: soundManager)
        }
        .onAppear {
            viewModel.onFinish = { [weak soundManager] in
                soundManager?.playFinishSound()
            }
        }
    }

    // MARK: - Duration Stepper

    private var durationStepper: some View {
        HStack(spacing: Theme.Dimension.durationStepperSpacing) {
            Button {
                viewModel.setDuration(
                    max(Theme.TimerMechanic.minimumDuration,
                        viewModel.totalDuration - Theme.TimerMechanic.durationStep)
                )
            } label: {
                Image(systemName: Theme.Symbol.decrement)
                    .font(.title3)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }
            .disabled(viewModel.state != .notStarted)
            .accessibilityLabel(Theme.Label.decrementDuration)

            Text("\(viewModel.totalDuration / 60)m \(viewModel.totalDuration % 60)s")
                .font(.title3.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Theme.ColorValue.textPrimary)

            Button {
                viewModel.setDuration(
                    viewModel.totalDuration + Theme.TimerMechanic.durationStep
                )
            } label: {
                Image(systemName: Theme.Symbol.increment)
                    .font(.title3)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }
            .disabled(viewModel.state != .notStarted)
            .accessibilityLabel(Theme.Label.incrementDuration)
        }
    }

    // MARK: - Timer Circle Button

    /// The entire timer circle acts as the Play/Pause button.
    private var timerCircleButton: some View {
        ZStack {
            TimerVisualView(
                elapsedFraction: elapsedFraction,
                fillColor: viewModel.timerColor
            )

            if let icon = centerIcon {
                Image(systemName: icon)
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .contentShape(Circle())
        .onTapGesture {
            handleCircleTap()
        }
    }

    /// Which SF Symbol to show centered in the circle, if any.
    private var centerIcon: String? {
        switch viewModel.state {
        case .notStarted, .paused:
            return Theme.Symbol.play
        case .running:
            return Theme.Symbol.pause
        case .finished:
            return nil
        }
    }

    private func handleCircleTap() {
        switch viewModel.state {
        case .notStarted, .paused:
            viewModel.play()
        case .running:
            viewModel.pause()
        case .finished:
            break
        }
    }

    // MARK: - Reset Button

    /// Always reserves space at the bottom-right so the layout
    /// doesn't shift when the Reset button appears or disappears.
    private var resetButton: some View {
        HStack {
            Spacer()
            Button {
                viewModel.reset()
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
            .accessibilityLabel(Theme.Label.reset)
        }
        .opacity(viewModel.state == .paused ? 1 : 0)
    }

    // MARK: - Derived Values

    /// 0.0 when the timer is full, 1.0 when fully depleted.
    /// Once the timer leaves `.notStarted` the pie jumps one notch
    /// ahead so the depletion is visible immediately on start.
    private var elapsedFraction: Double {
        guard viewModel.totalDuration > 0 else { return 0 }
        let notch = viewModel.state == .notStarted ? 0 : 1
        let raw = Double(viewModel.totalDuration - viewModel.timeRemaining + notch)
            / Double(viewModel.totalDuration)
        return min(raw, 1.0)
    }

    // MARK: - Settings Gear

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

#Preview {
    ContentView()
}

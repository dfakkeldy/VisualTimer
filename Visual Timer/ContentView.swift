import SwiftUI

/// Root view that composes the timer sub-views, wires the ViewModel
/// and SoundManager together, and presents the settings sheet.
///
/// The view itself owns no layout logic — it delegates to
/// `TimerVisualView`, `TimeDisplayView`, and `ControlRingView`.
struct ContentView: View {

    @StateObject private var viewModel = TimerViewModel()
    @StateObject private var soundManager = SoundManager()

    @State private var showSettings = false

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.ColorValue.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ControlRingView(
                    state: viewModel.state,
                    totalDuration: viewModel.totalDuration,
                    onDecrement: { viewModel.setDuration(
                        max(Theme.TimerMechanic.minimumDuration,
                            viewModel.totalDuration - Theme.TimerMechanic.durationStep)
                    ) },
                    onIncrement: { viewModel.setDuration(
                        viewModel.totalDuration + Theme.TimerMechanic.durationStep
                    ) },
                    onPlay: { viewModel.play() },
                    onPause: { viewModel.pause() },
                    onReset: { viewModel.reset() }
                )

                Spacer()

                TimerVisualView(
                    elapsedFraction: elapsedFraction,
                    animatingValue: viewModel.timeRemaining
                )

                TimeDisplayView(timeRemaining: viewModel.timeRemaining)
                    .padding(.top, Theme.Dimension.sectionSpacingSmall)

                Spacer()
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

    // MARK: - Derived Values

    /// 0.0 when the timer is full, 1.0 when fully depleted.
    private var elapsedFraction: Double {
        guard viewModel.totalDuration > 0 else { return 0 }
        return Double(viewModel.totalDuration - viewModel.timeRemaining)
            / Double(viewModel.totalDuration)
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

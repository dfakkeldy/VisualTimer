import SwiftUI

/// The duration stepper (only visible before the timer starts) and
/// the state-dependent circular Play / Pause / Unpause+Reset buttons.
struct ControlRingView: View {

    let state: TimerState
    let totalDuration: Int

    var onDecrement: () -> Void
    var onIncrement: () -> Void
    var onPlay: () -> Void
    var onPause: () -> Void
    var onReset: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            durationStepper
                .opacity(state == .notStarted ? 1 : 0)

            actionButtons
                .padding(.top, Theme.Dimension.sectionSpacingLarge)
        }
    }

    // MARK: - Duration Stepper

    private var durationStepper: some View {
        HStack(spacing: Theme.Dimension.durationStepperSpacing) {
            Button {
                onDecrement()
            } label: {
                Image(systemName: Theme.Symbol.decrement)
                    .font(.title3)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }
            .disabled(state != .notStarted)
            .accessibilityLabel(Theme.Label.decrementDuration)

            Text("\(totalDuration / 60)m \(totalDuration % 60)s")
                .font(.title3.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Theme.ColorValue.textPrimary)

            Button {
                onIncrement()
            } label: {
                Image(systemName: Theme.Symbol.increment)
                    .font(.title3)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }
            .disabled(state != .notStarted)
            .accessibilityLabel(Theme.Label.incrementDuration)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: Theme.Dimension.controlButtonSpacing) {
            switch state {
            case .notStarted:
                CircularButton(
                    symbol: Theme.Symbol.play,
                    label: Theme.Label.play,
                    action: onPlay
                )

            case .running:
                CircularButton(
                    symbol: Theme.Symbol.pause,
                    label: Theme.Label.pause,
                    action: onPause
                )

            case .paused:
                CircularButton(
                    symbol: Theme.Symbol.play,
                    label: Theme.Label.unpause,
                    action: onPlay
                )
                CircularButton(
                    symbol: Theme.Symbol.reset,
                    label: Theme.Label.reset,
                    action: onReset
                )

            case .finished:
                EmptyView()
            }
        }
    }
}

// MARK: - Circular Button

private struct CircularButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Theme.ColorValue.buttonFill)
                .frame(
                    width: Theme.Dimension.controlButtonSize,
                    height: Theme.Dimension.controlButtonSize
                )
                .overlay {
                    Image(systemName: symbol)
                        .font(.title2.weight(.medium))
                        .foregroundStyle(Theme.ColorValue.textPrimary)
                }
        }
        .accessibilityLabel(label)
    }
}

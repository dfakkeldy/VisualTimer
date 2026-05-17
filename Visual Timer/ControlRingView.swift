import SwiftUI

/// The state-dependent circular Play / Pause / Unpause+Reset buttons
/// shown at the bottom of the screen.
struct ControlRingView: View {

    let state: TimerState

    var onPlay: () -> Void
    var onPause: () -> Void
    var onReset: () -> Void

    var body: some View {
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

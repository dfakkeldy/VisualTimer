import SwiftUI

/// Displays the remaining time as `MM:SS`: light on the ink canvas, no box.
struct TimeDisplayView: View {
    let timeRemaining: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(TimerText.clock(timeRemaining))
            .accessibilityIdentifier("timer.time-remaining")
            .font(.system(
                size: Theme.TimerStyle.digitsSize,
                weight: .semibold,
                design: .rounded
            ))
            .monospacedDigit()
            .contentTransition(.numericText(countsDown: true))
            .animation(reduceMotion ? nil : .easeOut(duration: Theme.AnimationValue.stateTransitionDuration), value: timeRemaining)
            .foregroundStyle(Theme.ColorValue.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

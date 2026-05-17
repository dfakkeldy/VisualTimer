import SwiftUI

/// Displays the remaining time as `MM:SS` inside a subtle capsule.
struct TimeDisplayView: View {
    let timeRemaining: Int

    var body: some View {
        Text(formattedTime)
            .font(.system(
                size: Theme.Dimension.timeFontSize,
                weight: .bold,
                design: .monospaced
            ))
            .foregroundStyle(Theme.ColorValue.textPrimary)
            .padding(.horizontal, Theme.Dimension.timePillHorizontalPadding)
            .padding(.vertical, Theme.Dimension.timePillVerticalPadding)
            .background(
                Capsule()
                    .fill(Theme.ColorValue.pillBackground)
            )
    }

    private var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

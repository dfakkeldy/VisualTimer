import SwiftUI

/// Collapsed row showing one round in the editor list.
struct PlayerRowView: View {

    let round: Round
    let onTap: () -> Void
    let onToggleActive: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.horizontal.3")
                .font(.caption)
                .foregroundStyle(Theme.ColorValue.textSecondary)

            // Active toggle
            Button(action: onToggleActive) {
                Image(systemName: round.isActive
                    ? Theme.Symbol.activeToggle
                    : Theme.Symbol.inactiveToggle)
                    .font(.caption)
                    .foregroundStyle(round.isActive
                        ? round.color.swiftUIColor
                        : Theme.ColorValue.textSecondary)
            }

            // Emoji
            if !round.emoji.isEmpty {
                Text(round.emoji)
                    .font(.title3)
            }

            // Name
            Text(round.name)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.ColorValue.textPrimary)

            Spacer()

            // Duration
            Text(round.durationDisplay)
                .font(.body.monospacedDigit())
                .foregroundStyle(Theme.ColorValue.textSecondary)

            // Start paused indicator
            if round.startPaused {
                Image(systemName: Theme.Symbol.startPaused)
                    .font(.caption)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }
        }
        .opacity(round.isActive ? 1 : 0.4)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

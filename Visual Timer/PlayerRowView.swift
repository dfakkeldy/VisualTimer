import SwiftUI

/// One round in the editor list: a colour tile with its emoji, the name, the
/// time, and a visible checkbox that includes or skips it.
struct PlayerRowView: View {

    let round: Round
    let onTap: () -> Void
    let onToggleActive: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    RoundTile(round: round)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(round.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.ColorValue.textPrimary)
                            .lineLimit(1)
                        if round.startPaused || !round.countsAsPlayer {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(Theme.ColorValue.textTertiary)
                                .lineLimit(1)
                        }
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    Text(round.durationDisplay)
                        .font(.body.monospacedDigit())
                        .foregroundStyle(Theme.ColorValue.textSecondary)
                        .fixedSize()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit round")

            Button(action: onToggleActive) {
                Image(systemName: round.isActive ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(round.isActive ? Theme.ColorValue.textPrimary.opacity(0.7) : Theme.ColorValue.textTertiary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(round.isActive ? "Included" : "Skipped")
            .accessibilityHint(round.isActive ? "Skip this round" : "Include this round")
        }
        .opacity(round.isActive ? 1 : 0.5)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: Theme.Symbol.delete)
            }
        }
    }

    private var detail: String {
        var parts: [String] = []
        if !round.countsAsPlayer { parts.append("Break, not a turn") }
        if round.startPaused { parts.append("Waits for a tap") }
        return parts.joined(separator: " · ")
    }
}

/// A round's identity mark: its emoji on a tile of its colour.
struct RoundTile: View {
    let round: Round
    var size: CGFloat = 36

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(round.color.swiftUIColor)
            .overlay {
                if round.emoji.isEmpty {
                    Circle().fill(round.color.swiftUIColor).frame(width: size * 0.32)
                } else {
                    Text(round.emoji).font(.system(size: size * 0.52))
                }
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

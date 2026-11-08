import SwiftUI

/// The three pictures of a session's totals; the last one chosen is kept.
enum SessionTotalsStyle: String, CaseIterable, Identifiable {
    case pie, bars, turns

    static let storageKey = "historyTotalsStyle"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pie: return "Pie"
        case .bars: return "Bars"
        case .turns: return "Turns"
        }
    }
}

/// One name's totals, ready to draw.
struct SessionTotalEntry: Identifiable, Equatable {
    struct Turn: Equatable {
        let seconds: Int
        let isDimmed: Bool
    }

    let id: String
    /// "🦊 Maya"
    let label: String
    let color: Color
    let seconds: Int
    let turnCount: Int
    let averageSeconds: Int
    let turns: [Turn]

    func percent(of total: Int) -> Int {
        Int((Double(seconds) / Double(max(total, 1)) * 100).rounded())
    }

    /// "3m 43s · 2 turns · avg 1m 52s"
    var detail: String {
        let turnsText = turnCount == 1 ? "1 turn" : "\(turnCount) turns"
        return "\(TimerText.units(seconds)) · \(turnsText) · avg \(TimerText.units(averageSeconds))"
    }
}

// MARK: - Pie

/// Each name's share as a ring, clockwise from twelve in the order they
/// first ran. The total is already in the stats row, so the centre names the
/// split instead.
struct SessionTotalsPie: View {
    let entries: [SessionTotalEntry]
    let totalSeconds: Int

    private typealias Style = Theme.HistoryTotals

    var body: some View {
        HStack(alignment: .center, spacing: Style.pieSpacing) {
            ZStack {
                Canvas { context, size in
                    let lineWidth: CGFloat = Style.ringWidth
                    let radius: CGFloat = (min(size.width, size.height) - lineWidth) / 2
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    var start = Theme.Rotation.trimOriginOffset
                    for entry in entries {
                        let sweep = Double(entry.seconds) / Double(max(totalSeconds, 1)) * 360
                        var arc = Path()
                        arc.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(start + sweep), clockwise: false)
                        context.stroke(arc, with: .color(entry.color), lineWidth: lineWidth)
                        if entries.count > 1 {
                            let radians = start * .pi / 180
                            let inner: CGFloat = radius - lineWidth / 2
                            let outer: CGFloat = radius + lineWidth / 2
                            var seam = Path()
                            seam.move(to: CGPoint(x: center.x + inner * cos(radians), y: center.y + inner * sin(radians)))
                            seam.addLine(to: CGPoint(x: center.x + outer * cos(radians), y: center.y + outer * sin(radians)))
                            context.stroke(seam, with: .color(Theme.TimerStyle.ink), lineWidth: Style.seamWidth)
                        }
                        start += sweep
                    }
                }
                Text("by name")
                    .font(.caption)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }
            .frame(width: Style.pieSize, height: Style.pieSize)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Style.rowSpacing) {
                ForEach(entries) { entry in
                    HStack(spacing: 8) {
                        Text(entry.label)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ColorValue.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(TimerText.units(entry.seconds))
                            .font(.subheadline.weight(.medium).monospacedDigit())
                            .foregroundStyle(entry.color)
                        Text("\(entry.percent(of: totalSeconds))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.ColorValue.textSecondary)
                            .frame(width: Style.percentWidth, alignment: .trailing)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(entry.label), \(TimerText.units(entry.seconds)), \(entry.percent(of: totalSeconds)) percent")
                }
            }
        }
    }
}

// MARK: - Bars

/// One line per name, in the order they first ran; each bar is as long as
/// that name's share of the longest total, so length shows the ranking.
struct SessionTotalsBars: View {
    let entries: [SessionTotalEntry]
    let totalSeconds: Int

    private typealias Style = Theme.HistoryTotals

    var body: some View {
        let longest = max(entries.map { $0.seconds }.max() ?? 1, 1)
        VStack(alignment: .leading, spacing: Style.rowSpacing) {
            ForEach(entries) { entry in
                HStack(alignment: .center, spacing: 10) {
                    Text(entry.label)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ColorValue.textPrimary)
                        .lineLimit(1)
                        .frame(width: Style.labelWidth, alignment: .leading)
                    GeometryReader { proxy in
                        let width: CGFloat = proxy.size.width * CGFloat(entry.seconds) / CGFloat(longest)
                        Capsule()
                            .fill(entry.color)
                            .frame(width: max(width, Style.barMinWidth), height: Style.barHeight)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: Style.barHeight)
                    Text(TimerText.units(entry.seconds))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.ColorValue.textSecondary)
                        .frame(width: Style.valueWidth, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(entry.label), \(entry.detail), \(entry.percent(of: totalSeconds)) percent")
            }
        }
    }
}

// MARK: - Turns

/// One row per name, one block per turn in the order played, all on the same
/// scale, each with its length beneath, so steady turns and slow ones show
/// at a glance.
struct SessionTotalsTurns: View {
    let entries: [SessionTotalEntry]

    private typealias Style = Theme.HistoryTotals

    var body: some View {
        let widest = max(entries.map { $0.seconds }.max() ?? 1, 1)
        let hasDimmed = entries.contains { $0.turns.contains { $0.isDimmed } }
        VStack(alignment: .leading, spacing: Style.rowSpacing) {
            ForEach(entries) { entry in
                HStack(alignment: .top, spacing: 10) {
                    Text(entry.label)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ColorValue.textPrimary)
                        .lineLimit(1)
                        .frame(width: Style.labelWidth, alignment: .leading)
                    GeometryReader { proxy in
                        let gaps: CGFloat = Style.turnGap * CGFloat(max(entry.turns.count - 1, 0))
                        let scale: CGFloat = max(proxy.size.width - gaps, 0) / CGFloat(widest)
                        HStack(alignment: .top, spacing: Style.turnGap) {
                            ForEach(Array(entry.turns.enumerated()), id: \.offset) { _, turn in
                                let width: CGFloat = max(scale * CGFloat(turn.seconds), Style.barMinWidth)
                                VStack(alignment: .leading, spacing: 3) {
                                    Capsule()
                                        .fill(entry.color.opacity(turn.isDimmed ? Theme.HistoryTimeline.dimmedOpacity : 1))
                                        .frame(width: width, height: Style.barHeight)
                                    Text(TimerText.units(turn.seconds))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(Theme.ColorValue.textSecondary)
                                        .lineLimit(1)
                                        .fixedSize()
                                        .frame(width: width, alignment: .leading)
                                }
                            }
                        }
                    }
                    .frame(height: Style.rowHeight)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(entry.label), turns of \(entry.turns.map { TimerText.units($0.seconds) }.joined(separator: ", "))")
            }
            Text(hasDimmed
                 ? "One block per turn, in the order played. Faded turns were skipped or restarted."
                 : "One block per turn, in the order played.")
                .font(.caption)
                .foregroundStyle(Theme.ColorValue.textSecondary)
        }
    }
}

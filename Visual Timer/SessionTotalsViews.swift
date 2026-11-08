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

/// The one-line key every totals view ends on, at the same baseline.
struct SessionTotalsKey: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Theme.ColorValue.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Pie

/// Each name's share as a ring, clockwise from twelve in the order they
/// first ran. The centre stays empty: the ring is the whole session.
struct SessionTotalsPie: View {
    let entries: [SessionTotalEntry]
    let totalSeconds: Int

    /// The ring sweeps once from twelve, as the dial does.
    @State private var swept = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias Style = Theme.HistoryTotals

    var body: some View {
        VStack(alignment: .leading, spacing: Style.keySpacing) {
            HStack(alignment: .center, spacing: Style.pieSpacing) {
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
                .frame(width: Style.pieSize, height: Style.pieSize)
                .mask {
                    Circle()
                        .trim(from: 0, to: swept ? 1 : 0)
                        .stroke(lineWidth: Style.ringWidth * 2)
                        .rotationEffect(.degrees(Theme.Rotation.trimOriginOffset))
                }
                .onAppear {
                    guard !swept else { return }
                    if reduceMotion {
                        swept = true
                    } else {
                        withAnimation(.easeOut(duration: Style.sweepDuration)) { swept = true }
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Style.rowSpacing) {
                    ForEach(entries) { entry in
                        HStack(spacing: 8) {
                            Capsule()
                                .fill(entry.color)
                                .frame(width: Style.legendMarkWidth, height: Style.barHeight)
                                .accessibilityHidden(true)
                            Text(entry.label)
                                .font(.subheadline)
                                .foregroundStyle(Theme.ColorValue.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(TimerText.units(entry.seconds))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(Theme.ColorValue.textSecondary)
                            Text("\(entry.percent(of: totalSeconds))%")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(Theme.ColorValue.textSecondary)
                                .frame(width: Style.percentWidth, alignment: .trailing)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(entry.label), \(TimerText.units(entry.seconds)), \(entry.percent(of: totalSeconds)) percent")
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            SessionTotalsKey(text: "Each name's share of the session.")
        }
    }
}

// MARK: - Bars

/// The typical turn: one line per name, in the order they first ran, each
/// bar its average turn on a faint track whose full width is the longest
/// average. Pie answers "who took the most time"; this answers "whose turns
/// run long".
struct SessionTotalsBars: View {
    let entries: [SessionTotalEntry]
    let totalSeconds: Int

    private typealias Style = Theme.HistoryTotals

    var body: some View {
        let longest = max(entries.map { $0.averageSeconds }.max() ?? 1, 1)
        VStack(alignment: .leading, spacing: Style.keySpacing) {
            VStack(alignment: .leading, spacing: Style.rowSpacing) {
                ForEach(entries) { entry in
                    HStack(alignment: .center, spacing: 10) {
                        Text(entry.label)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ColorValue.textPrimary)
                            .lineLimit(1)
                            .frame(width: Style.labelWidth, alignment: .leading)
                        GeometryReader { proxy in
                            let width: CGFloat = proxy.size.width * CGFloat(entry.averageSeconds) / CGFloat(longest)
                            ZStack(alignment: .leading) {
                                Capsule().fill(Style.track)
                                Capsule()
                                    .fill(entry.color)
                                    .frame(width: max(width, Style.barMinWidth))
                            }
                            .frame(height: Style.barHeight)
                            .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: Style.rowHeight)
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(TimerText.units(entry.averageSeconds))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(Theme.ColorValue.textSecondary)
                            Text(entry.turnCount == 1 ? "1 turn" : "\(entry.turnCount) turns")
                                .font(.caption2)
                                .foregroundStyle(Theme.ColorValue.textSecondary)
                        }
                        .frame(width: Style.valueWidth, alignment: .trailing)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(entry.label), average turn \(TimerText.units(entry.averageSeconds)), \(entry.turnCount == 1 ? "1 turn" : "\(entry.turnCount) turns")")
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            SessionTotalsKey(text: "Average turn for each name. Full width is the longest.")
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
        VStack(alignment: .leading, spacing: Style.keySpacing) {
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
                            Capsule()
                                .fill(Style.track)
                                .frame(width: proxy.size.width, height: Style.barHeight)
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
            }
            .frame(maxHeight: .infinity, alignment: .top)
            SessionTotalsKey(text: hasDimmed
                ? "One block per turn, in the order played. Faded turns were skipped or restarted."
                : "One block per turn, in the order played.")
        }
    }
}

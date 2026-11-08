import SwiftUI

/// One round's stretch of the session spine. Its colour is exactly as tall as
/// the round's share of the session; any extra height the row needs for its
/// label continues as a neutral hairline, so colour never overstates time.
/// Paused stretches are hatched. Each turn is its own rounded block.
struct TimelineSpineSegment: View {
    let color: Color
    /// The colour's height in points: the round's true share.
    let trueHeight: CGFloat
    /// Paused stretches as fractions of this round, 0 at its start.
    let pauses: [ClosedRange<Double>]
    let isDimmed: Bool
    let roundsTop: Bool
    let roundsBottom: Bool

    private typealias Style = Theme.HistoryTimeline

    var body: some View {
        let radius: CGFloat = Style.spineRadius
        let top: CGFloat = roundsTop ? radius : 0
        let bottom: CGFloat = roundsBottom ? radius : 0
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: top,
            bottomLeadingRadius: bottom,
            bottomTrailingRadius: bottom,
            topTrailingRadius: top,
            style: .continuous
        )
        GeometryReader { proxy in
            let available: CGFloat = proxy.size.height
            let colourHeight: CGFloat = min(max(trueHeight, 1), available)
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Style.eventLine)
                    .frame(width: Style.eventLineWidth, height: available)
                ZStack(alignment: .top) {
                    shape.fill(color.opacity(isDimmed ? Style.dimmedOpacity : 1))
                    ForEach(Array(pauses.enumerated()), id: \.offset) { _, pause in
                        PauseHatch()
                            .frame(height: max(colourHeight * CGFloat(pause.upperBound - pause.lowerBound), 1))
                            .frame(maxHeight: .infinity, alignment: .top)
                            .offset(y: colourHeight * CGFloat(pause.lowerBound))
                    }
                }
                .clipShape(shape)
                .frame(height: colourHeight)
            }
            .frame(width: proxy.size.width, alignment: .top)
        }
        .frame(width: Style.spineWidth)
        .accessibilityHidden(true)
    }
}

/// A paused stretch: the round's colour shaded and crossed with fine
/// diagonal lines, readable on every palette colour.
private struct PauseHatch: View {
    private typealias Style = Theme.HistoryTimeline

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Style.pauseShade))
            var lines = Path()
            let step: CGFloat = Style.hatchSpacing
            var x: CGFloat = -size.height
            while x < size.width {
                lines.move(to: CGPoint(x: x, y: size.height))
                lines.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += step
            }
            context.stroke(lines, with: .color(Style.hatchLine), lineWidth: Style.hatchLineWidth)
        }
    }
}

/// The spine's end: one outlined ring with a check (or a stop for a session
/// ended early). The session's colours already have their circle in Totals.
struct TimelineFinishMark: View {
    let endedEarly: Bool

    var body: some View {
        ZStack {
            Circle().strokeBorder(Theme.ColorValue.textSecondary, lineWidth: Theme.HistoryTimeline.finishRingWidth)
            Image(systemName: endedEarly ? Theme.HistoryTimeline.endedSymbol : Theme.HistoryTimeline.finishedSymbol)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.ColorValue.textSecondary)
        }
        .accessibilityHidden(true)
    }
}

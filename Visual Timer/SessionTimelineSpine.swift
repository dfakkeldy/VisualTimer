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

/// The moment someone went back: one glyph on the spine, taking no time.
struct TimelineEventMark: View {
    let symbol: String

    private typealias Style = Theme.HistoryTimeline

    var body: some View {
        Image(systemName: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.ColorValue.textPrimary)
            .frame(width: Style.eventGlyphSize, height: Style.eventGlyphSize)
            .background(Theme.ColorValue.appBackground, in: Circle())
            .accessibilityHidden(true)
    }
}

/// The spine's end: the session's rounds as one flat disc, clockwise from
/// twelve in the order they ran, seamed in ink like the spine.
struct TimelineFinishDisc: View {
    let segments: [SequenceSegment]

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius: CGFloat = min(size.width, size.height) / 2
            let total = Double(max(segments.reduce(0) { $0 + $1.seconds }, 1))
            var start = Theme.Rotation.trimOriginOffset
            for segment in segments {
                let sweep = Double(segment.seconds) / total * 360
                var wedge = Path()
                wedge.move(to: center)
                wedge.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(start + sweep), clockwise: false)
                wedge.closeSubpath()
                context.fill(wedge, with: .color(segment.color))
                if segments.count > 1 {
                    context.stroke(wedge, with: .color(Theme.TimerStyle.ink), lineWidth: Theme.HistoryTimeline.seam)
                }
                start += sweep
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

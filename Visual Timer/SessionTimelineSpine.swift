import SwiftUI

/// One round's stretch of the session spine: its colour, as tall as the row
/// it sits beside, with paused stretches shaded darker. Only the spine's two
/// ends are rounded, so the rounds read as one continuous length of time.
struct TimelineSpineSegment: View {
    let color: Color
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
            let height: CGFloat = proxy.size.height
            ZStack(alignment: .top) {
                shape.fill(color.opacity(isDimmed ? Style.dimmedOpacity : 1))
                ForEach(Array(pauses.enumerated()), id: \.offset) { _, pause in
                    pauseBand(pause, height: height)
                }
            }
            .clipShape(shape)
        }
        .frame(width: Style.spineWidth)
        .padding(.bottom, roundsBottom ? 0 : Style.seam)
        .accessibilityHidden(true)
    }

    private func pauseBand(_ pause: ClosedRange<Double>, height: CGFloat) -> some View {
        let y: CGFloat = height * CGFloat(pause.lowerBound)
        let length: CGFloat = height * CGFloat(pause.upperBound - pause.lowerBound)
        return Rectangle()
            .fill(Style.pauseShade)
            .frame(height: max(length, 1))
            .frame(maxHeight: .infinity, alignment: .top)
            .offset(y: y)
    }
}

/// A moment on the spine (someone went back): the spine thins to a hairline
/// and carries one glyph, so a moment never looks like a stretch of time.
struct TimelineEventMark: View {
    let symbol: String

    private typealias Style = Theme.HistoryTimeline

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Style.eventLine)
                .frame(width: Style.eventLineWidth)
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ColorValue.textPrimary)
                .frame(width: Style.eventGlyphSize, height: Style.eventGlyphSize)
                .background(Theme.ColorValue.appBackground, in: Circle())
        }
        .accessibilityHidden(true)
    }
}

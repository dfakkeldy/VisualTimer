import SwiftUI

/// A past session as one horizontal bar: each round as wide as its share of
/// the session, paused stretches shaded, and a tick wherever someone went back.
/// Tapping picks the round under the finger; the caller owns the selection.
struct SessionTimelineBar: View {

    struct Segment: Identifiable, Equatable {
        let id: Int
        let color: Color
        /// Start and width as fractions of the whole session.
        let start: Double
        let width: Double
        let emoji: String
        let isException: Bool
        /// Paused stretches as fractions of the whole session.
        let pauses: [ClosedRange<Double>]
    }

    let segments: [Segment]
    /// Positions of "went back" moments, as fractions of the session.
    let markers: [Double]
    let selectedID: Int?
    let accessibilitySummary: String
    let accessibilitySelection: String
    let onSelect: (Int?) -> Void

    private typealias Style = Theme.HistoryTimeline

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                ForEach(segments) { segment in
                    segmentView(segment, totalWidth: width)
                }
                ForEach(Array(markers.enumerated()), id: \.offset) { _, position in
                    markerView(atX: markerX(position, totalWidth: width))
                }
            }
            .frame(width: width, height: Style.barHeight, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                onSelect(segmentID(atX: location.x, totalWidth: width))
            }
        }
        .frame(height: Style.barHeight)
        .padding(.vertical, Style.markerOverhang)
        .animation(.easeOut(duration: Style.selectionAnimation), value: selectedID)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityValue(accessibilitySelection)
        .accessibilityHint("Swipe up or down to step through the rounds.")
        .accessibilityIdentifier(Style.barIdentifier)
        .accessibilityAdjustableAction { direction in
            step(direction == .increment ? 1 : -1)
        }
    }

    private func segmentView(_ segment: Segment, totalWidth: CGFloat) -> some View {
        let (x, width) = drawnSpan(segment, totalWidth: totalWidth)
        let isSelected = selectedID == segment.id
        let isDimmed = selectedID != nil && !isSelected
        let shape = RoundedRectangle(cornerRadius: Style.segmentCornerRadius, style: .continuous)

        return shape
            .fill(segment.color.opacity(segment.isException ? Style.exceptionOpacity : 1))
            .overlay(alignment: .topLeading) {
                ForEach(Array(segment.pauses.enumerated()), id: \.offset) { _, pause in
                    pauseShade(pause, totalWidth: totalWidth, segmentX: x)
                }
            }
            .clipShape(shape)
            .overlay {
                if width >= Style.emojiMinWidth, !segment.emoji.isEmpty {
                    Text(segment.emoji)
                        .font(.callout)
                        .lineLimit(1)
                }
            }
            .overlay {
                if isSelected {
                    shape.strokeBorder(Theme.ColorValue.textPrimary, lineWidth: Style.selectionStroke)
                }
            }
            .opacity(isDimmed ? Style.dimmedOpacity : 1)
            .frame(width: width, height: Style.barHeight)
            .offset(x: x)
    }

    /// A paused stretch, placed relative to its segment's leading edge.
    private func pauseShade(_ pause: ClosedRange<Double>, totalWidth: CGFloat, segmentX: CGFloat) -> some View {
        let lower: CGFloat = totalWidth * CGFloat(pause.lowerBound)
        let length: CGFloat = totalWidth * CGFloat(pause.upperBound - pause.lowerBound)
        return Rectangle()
            .fill(Style.pauseShade)
            .frame(width: max(length, 1), height: Style.barHeight)
            .offset(x: lower - segmentX)
    }

    private func markerView(atX x: CGFloat) -> some View {
        let height: CGFloat = Style.barHeight + Style.markerOverhang * 2
        return Capsule()
            .fill(Style.marker)
            .frame(width: Style.markerWidth, height: height)
            .offset(x: x, y: -Style.markerOverhang)
    }

    /// A marker's leading edge, centred on its moment and kept inside the bar.
    private func markerX(_ position: Double, totalWidth: CGFloat) -> CGFloat {
        let centred: CGFloat = totalWidth * CGFloat(position) - Style.markerWidth / 2
        let upper: CGFloat = max(totalWidth - Style.markerWidth, 0)
        return min(max(centred, 0), upper)
    }

    /// Where a segment is drawn, in points: never thinner than the minimum,
    /// never past the bar's end.
    private func drawnSpan(_ segment: Segment, totalWidth: CGFloat) -> (x: CGFloat, width: CGFloat) {
        let gap = segment.id == segments.last?.id ? 0 : Style.segmentGap
        let start: CGFloat = totalWidth * CGFloat(segment.start)
        let x: CGFloat = min(start, max(totalWidth - Style.segmentMinWidth, 0))
        let drawn: CGFloat = totalWidth * CGFloat(segment.width) - gap
        let width: CGFloat = max(drawn, Style.segmentMinWidth)
        return (x, min(width, totalWidth - x))
    }

    /// The round under a tap. Each round answers across at least a finger's
    /// width, the narrowest wins, so thin rounds stay reachable. Tapping the
    /// selected round again clears the selection.
    private func segmentID(atX tapX: CGFloat, totalWidth: CGFloat) -> Int? {
        func reach(_ segment: Segment) -> (lower: CGFloat, upper: CGFloat, width: CGFloat) {
            let (x, width) = drawnSpan(segment, totalWidth: totalWidth)
            let pad = max(Style.minimumHitWidth - width, 0) / 2
            return (x - pad, x + width + pad, width)
        }
        let hit = segments
            .map { ($0, reach($0)) }
            .filter { tapX >= $0.1.lower && tapX <= $0.1.upper }
            .min { $0.1.width < $1.1.width }?.0
            ?? segments.min { abs(tapX - center($0, totalWidth)) < abs(tapX - center($1, totalWidth)) }
        guard let hit else { return nil }
        return hit.id == selectedID ? nil : hit.id
    }

    private func center(_ segment: Segment, _ totalWidth: CGFloat) -> CGFloat {
        let (x, width) = drawnSpan(segment, totalWidth: totalWidth)
        return x + width / 2
    }

    private func step(_ delta: Int) {
        guard !segments.isEmpty else { return }
        let current = segments.firstIndex { $0.id == selectedID }
        let next: Int
        if let current {
            next = min(max(current + delta, 0), segments.count - 1)
        } else {
            next = delta > 0 ? 0 : segments.count - 1
        }
        onSelect(segments[next].id)
    }
}

/// A hairline track the width of the session, with this round's stretch on it,
/// so each list row shows where it fell.
struct SessionTimelineTrack: View {
    let color: Color
    let start: Double
    let width: Double
    var isException = false

    var body: some View {
        GeometryReader { proxy in
            let total: CGFloat = proxy.size.width
            let minWidth: CGFloat = Theme.HistoryTimeline.segmentMinWidth
            let length: CGFloat = max(total * CGFloat(width), minWidth)
            let x: CGFloat = min(total * CGFloat(start), total - minWidth)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ColorValue.surfaceStroke)
                Capsule()
                    .fill(color.opacity(isException ? Theme.HistoryTimeline.exceptionOpacity : 1))
                    .frame(width: length)
                    .offset(x: x)
            }
        }
        .frame(height: Theme.HistoryTimeline.rowTrackHeight)
        .accessibilityHidden(true)
    }
}

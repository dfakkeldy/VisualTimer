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
                    Capsule()
                        .fill(Style.marker)
                        .frame(width: Style.markerWidth, height: Style.barHeight + Style.markerOverhang * 2)
                        .offset(x: min(max(width * position - Style.markerWidth / 2, 0), width - Style.markerWidth),
                                y: -Style.markerOverhang)
                }
            }
            .frame(width: width, height: Style.barHeight, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                onSelect(segmentID(at: location.x / max(width, 1)))
            }
        }
        .frame(height: Style.barHeight)
        .padding(.vertical, Style.markerOverhang)
        .animation(.easeOut(duration: Style.selectionAnimation), value: selectedID)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityValue(accessibilitySelection)
        .accessibilityHint("Swipe up or down to step through the rounds.")
        .accessibilityAdjustableAction { direction in
            step(direction == .increment ? 1 : -1)
        }
    }

    private func segmentView(_ segment: Segment, totalWidth: CGFloat) -> some View {
        let x = totalWidth * segment.start
        let gap = segment.id == segments.last?.id ? 0 : Style.segmentGap
        let width = max(totalWidth * segment.width - gap, Style.segmentMinWidth)
        let isSelected = selectedID == segment.id
        let isDimmed = selectedID != nil && !isSelected
        let shape = RoundedRectangle(cornerRadius: Style.segmentCornerRadius, style: .continuous)

        return shape
            .fill(segment.color.opacity(segment.isException ? Style.exceptionOpacity : 1))
            .overlay(alignment: .topLeading) {
                ForEach(Array(segment.pauses.enumerated()), id: \.offset) { _, pause in
                    Rectangle()
                        .fill(Style.pauseShade)
                        .frame(width: max(totalWidth * (pause.upperBound - pause.lowerBound), 1),
                               height: Style.barHeight)
                        .offset(x: totalWidth * pause.lowerBound - x)
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

    /// The round under a tap, or the nearest one so thin rounds stay reachable.
    /// Tapping the selected round again clears the selection.
    private func segmentID(at position: Double) -> Int? {
        let hit = segments.first { position >= $0.start && position <= $0.start + $0.width }
            ?? segments.min { distance(position, $0) < distance(position, $1) }
        guard let hit else { return nil }
        return hit.id == selectedID ? nil : hit.id
    }

    private func distance(_ position: Double, _ segment: Segment) -> Double {
        abs(position - (segment.start + segment.width / 2))
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
            let total = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ColorValue.surfaceStroke)
                Capsule()
                    .fill(color.opacity(isException ? Theme.HistoryTimeline.exceptionOpacity : 1))
                    .frame(width: max(total * width, Theme.HistoryTimeline.segmentMinWidth))
                    .offset(x: min(total * start, total - Theme.HistoryTimeline.segmentMinWidth))
            }
        }
        .frame(height: Theme.HistoryTimeline.rowTrackHeight)
        .accessibilityHidden(true)
    }
}

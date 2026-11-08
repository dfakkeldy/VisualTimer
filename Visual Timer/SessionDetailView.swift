import SwiftUI

/// One past session: the short answer first (when, how long, what happened),
/// then the session as a horizontal timeline, then one row per round.
struct SessionDetailView: View {

    let record: GameRecord
    @ObservedObject var history: HistoryViewModel
    @ObservedObject var proAccess: ProAccessViewModel
    @Environment(\.dismiss) private var dismiss

    init(record: GameRecord, history: HistoryViewModel, proAccess: ProAccessViewModel) {
        self.record = record
        self._history = ObservedObject(wrappedValue: history)
        self._proAccess = ObservedObject(wrappedValue: proAccess)
    }

    @State private var showDeleteConfirmation = false
    @State private var showExporter = false
    @State private var requestedProFeature: ProFeature?
    /// The round picked on the timeline, by its index in the session's items.
    @State private var selectedIndex: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summary
                overview
                timeline
                deleteButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Theme.ColorValue.appBackground)
        .navigationTitle(record.gameTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    guard proAccess.isProUnlocked else {
                        requestedProFeature = .historyExport
                        return
                    }
                    if history.exportURL(for: record) != nil {
                        showExporter = true
                    }
                } label: {
                    Image(systemName: Theme.Symbol.proHistoryExport)
                }
                .accessibilityLabel(Theme.Label.export)
            }
        }
        .alert("Delete this session?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                history.deleteRecord(id: record.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(record.gameTitle)” is removed from History. This can't be undone.")
        }
        .sheet(isPresented: $showExporter) {
            if let url = history.exportURL(for: record) {
                ShareSheet(items: [url])
            }
        }
        .sheet(item: $requestedProFeature) { feature in
            ProPaywallView(feature: feature, proAccess: proAccess)
        }
    }

    // MARK: - Summary

    private var summary: some View {
        let session = record.session
        return VStack(alignment: .leading, spacing: 12) {
            Text("Started \(record.playedAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))")
                .font(.subheadline)
                .foregroundStyle(Theme.ColorValue.textSecondary)

            HStack(spacing: 8) {
                stat(TimerText.words(Int(session.totalElapsedSeconds)), "total")
                if session.pauseCount > 0 {
                    stat("\(session.pauseCount)", session.pauseCount == 1 ? "pause" : "pauses")
                }
                if session.skipCount > 0 {
                    stat("\(session.skipCount)", session.skipCount == 1 ? "skip" : "skips")
                }
                if session.doOverCount > 0 {
                    stat("\(session.doOverCount)", session.doOverCount == 1 ? "went back" : "went back")
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Theme.ColorValue.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.ColorValue.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.ColorValue.surface, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Timeline

    private var sessionTimeline: SessionTimeline { SessionTimeline(record: record) }

    /// The whole session left to right, each round as wide as its share.
    private var overview: some View {
        let timeline = sessionTimeline
        let items = timeline.items
        let segments: [SessionTimelineBar.Segment] = items.enumerated().compactMap { index, item in
            guard let placement = timeline.placement(of: item),
                  let color = timeline.color(for: item, in: record) else { return nil }
            return SessionTimelineBar.Segment(
                id: index,
                color: color,
                start: placement.start,
                width: placement.width,
                emoji: item.emoji,
                isException: item.outcome.isException,
                pauses: item.pauses.map { timeline.fraction(at: $0.lowerBound)...timeline.fraction(at: $0.upperBound) }
            )
        }
        let markers = items.filter { $0.outcome == .wentBack }.map { timeline.fraction(at: $0.startOffset) }
        let selected = selectedIndex.flatMap { items.indices.contains($0) ? items[$0] : nil }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ColorValue.textSecondary)

            SessionTimelineBar(
                segments: segments,
                markers: markers,
                selectedID: selectedIndex,
                accessibilitySummary: "Timeline, \(segments.count) \(segments.count == 1 ? "round" : "rounds") over \(TimerText.words(timeline.span))",
                accessibilitySelection: selected.map { selectionText($0, in: timeline) } ?? "No round selected",
                onSelect: { selectedIndex = $0 }
            )

            HStack {
                Text(clockText(offset: 0))
                Spacer(minLength: 8)
                Text(clockText(offset: timeline.span))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Theme.ColorValue.textTertiary)
            .accessibilityHidden(true)

            Group {
                if let selected {
                    Text(selectionText(selected, in: timeline))
                        .foregroundStyle(Theme.ColorValue.textPrimary)
                } else {
                    Text("Tap a round to see where it fell.")
                        .foregroundStyle(Theme.ColorValue.textTertiary)
                }
            }
            .font(.subheadline)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
        }
        .padding(14)
        .background(Theme.ColorValue.surface, in: .rect(cornerRadius: 16))
    }

    /// "🦊 Maya · 1:25 · 18% of the session · from 0:00"
    private func selectionText(_ item: SessionTimeline.Item, in timeline: SessionTimeline) -> String {
        var parts: [String] = [[item.emoji, item.name].filter { !$0.isEmpty }.joined(separator: " ")]
        if let length = item.length { parts.append(TimerText.length(length)) }
        if let percent = timeline.percent(of: item) { parts.append("\(percent)% of the session") }
        parts.append("from \(TimerText.length(item.startOffset))")
        if let note = item.note { parts.append(note) }
        return parts.joined(separator: " · ")
    }

    private func clockText(offset: Int) -> String {
        let start = record.session.events.first?.timestamp ?? record.playedAt
        return start.addingTimeInterval(TimeInterval(offset)).formatted(date: .omitted, time: .shortened)
    }

    private var timeline: some View {
        let timeline = sessionTimeline
        let items = timeline.items
        return VStack(alignment: .leading, spacing: 0) {
            Text("Rounds")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ColorValue.textSecondary)
                .padding(.bottom, 10)

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let color = timeline.color(for: item, in: record)
                let placement = timeline.placement(of: item)
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Group {
                            if let color {
                                Circle().fill(color)
                            } else if item.outcome == .sessionEnd {
                                // The finish, as the same pie the session ended on.
                                SequencePie(segments: finishSegments)
                            } else {
                                // Not a round: an event (back, end), shown as a hollow mark.
                                Circle().strokeBorder(Theme.ColorValue.textSecondary, lineWidth: 1.5)
                            }
                        }
                        .frame(width: item.outcome == .sessionEnd ? 14 : 9, height: item.outcome == .sessionEnd ? 14 : 9)
                        .padding(.top, item.outcome == .sessionEnd ? 3 : 6)
                        if index < items.count - 1 {
                            Rectangle()
                                .fill(Theme.ColorValue.surfaceStroke)
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 12)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            if !item.emoji.isEmpty {
                                Text(item.emoji).accessibilityHidden(true)
                            }
                            Text(item.name)
                                .font(item.length == nil ? .subheadline : .body.weight(.medium))
                                .foregroundStyle(item.length == nil ? Theme.ColorValue.textSecondary : Theme.ColorValue.textPrimary)
                            Spacer(minLength: 8)
                            if let length = item.length {
                                Text(TimerText.length(length))
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(Theme.ColorValue.textSecondary)
                            }
                        }
                        if let color, let placement {
                            SessionTimelineTrack(
                                color: color,
                                start: placement.start,
                                width: placement.width,
                                isException: item.outcome.isException
                            )
                        }
                        if let note = item.note {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(Theme.ColorValue.textTertiary)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        selectedIndex == index ? Theme.HistoryTimeline.selectionHighlight : .clear,
                        in: .rect(cornerRadius: Theme.HistoryTimeline.rowCornerRadius)
                    )
                    .padding(.bottom, 6)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard placement != nil else { return }
                    selectedIndex = selectedIndex == index ? nil : index
                }
                .animation(.easeOut(duration: Theme.HistoryTimeline.selectionAnimation), value: selectedIndex)
                .accessibilityElement(children: .combine)
                .accessibilityValue(timeline.percent(of: item).map { "\($0) percent of the session" } ?? "")
            }
        }
    }

    private var finishSegments: [SequenceSegment] {
        let timeline = sessionTimeline
        return timeline.items.enumerated().compactMap { index, item in
            guard let length = item.length, let color = timeline.color(for: item, in: record) else { return nil }
            return SequenceSegment(id: index, color: color, seconds: max(length, 1))
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete session", systemImage: Theme.Symbol.delete)
                .font(.body.weight(.medium))
        }
        .padding(.top, 8)
        .accessibilityLabel(Theme.Label.delete)
    }
}

// MARK: - Timeline model

/// Folds a session's raw events into one item per round played.
struct SessionTimeline {
    enum Outcome {
        case finished, skipped, wentBack, restarted, endedEarly, sessionEnd

        var isException: Bool {
            switch self {
            case .finished, .sessionEnd: return false
            default: return true
            }
        }

        var color: Color {
            switch self {
            case .skipped: return .yellow
            case .wentBack: return .purple
            case .restarted: return .mint
            case .endedEarly: return .orange
            case .finished, .sessionEnd: return Theme.ColorValue.textSecondary
            }
        }
    }

    struct Item {
        let name: String
        let emoji: String
        let startOffset: Int
        let length: Int?
        let outcome: Outcome
        let note: String?
        /// Paused stretches inside this round, in seconds from the session start.
        var pauses: [Range<Int>] = []
    }

    let items: [Item]
    /// Seconds from the first event to the last: the timeline's full width.
    let span: Int
    /// Distinct round names in the order they first ran, for fallback colours.
    private let roundOrder: [String]

    init(record: GameRecord) {
        let events = record.session.events
        guard let origin = events.first?.timestamp else {
            items = []
            span = 0
            roundOrder = []
            return
        }
        func offset(_ date: Date) -> Int { Int(max(date.timeIntervalSince(origin), 0)) }

        var result: [Item] = []
        var open: (name: String, emoji: String, start: Date, pauses: [Range<Int>], pausedAt: Date?)?

        func endPause(at date: Date) {
            guard let pausedAt = open?.pausedAt else { return }
            let lower = offset(pausedAt)
            open?.pauses.append(lower..<max(offset(date), lower))
            open?.pausedAt = nil
        }

        func close(at date: Date, _ outcome: Outcome, note: String? = nil) {
            endPause(at: date)
            guard let round = open else { return }
            var parts: [String] = []
            if let note { parts.append(note) }
            if !round.pauses.isEmpty { parts.append(round.pauses.count == 1 ? "1 pause" : "\(round.pauses.count) pauses") }
            result.append(Item(
                name: round.name,
                emoji: round.emoji,
                startOffset: offset(round.start),
                length: Int(max(date.timeIntervalSince(round.start), 0)),
                outcome: outcome,
                note: parts.isEmpty ? nil : parts.joined(separator: " · "),
                pauses: round.pauses
            ))
            open = nil
        }

        for event in events {
            switch event {
            case .roundStarted(let name, let emoji, let date):
                close(at: date, .finished)
                open = (name, emoji, date, [], nil)
            case .roundFinished(_, let date):
                close(at: date, .finished)
            case .skipped(_, let date):
                close(at: date, .skipped, note: "Skipped")
            case .doOver(let previous, let date):
                close(at: date, .finished, note: "Cut short")
                result.append(Item(name: "↩︎ Back to \(previous)", emoji: "", startOffset: offset(date), length: nil, outcome: .wentBack, note: nil))
            case .restartTimer(_, let date):
                close(at: date, .restarted, note: "Restarted")
            case .paused(let date):
                if open != nil, open?.pausedAt == nil { open?.pausedAt = date }
            case .resumed(let date):
                endPause(at: date)
            case .gameStarted:
                break
            case .gameEnded(let date):
                close(at: date, .endedEarly, note: "Session ended here")
                result.append(Item(name: "Finished", emoji: "", startOffset: offset(date), length: nil, outcome: .sessionEnd, note: nil))
            }
        }
        items = result
        let lastEnd = result.map { $0.startOffset + ($0.length ?? 0) }.max() ?? 0
        span = max(offset(events.last?.timestamp ?? origin), lastEnd)
        var order: [String] = []
        for item in result where item.length != nil && !order.contains(item.name) {
            order.append(item.name)
        }
        roundOrder = order
    }

    // MARK: Layout

    /// Where a round sits on the timeline, as fractions of the whole session.
    struct Placement: Equatable {
        let start: Double
        let width: Double
    }

    /// Nil for events (went back, finished), which have no length.
    func placement(of item: Item) -> Placement? {
        guard let length = item.length else { return nil }
        guard span > 0 else { return Placement(start: 0, width: 1) }
        let total = Double(span)
        let start = min(Double(item.startOffset) / total, 1)
        return Placement(start: start, width: min(Double(length) / total, 1 - start))
    }

    /// A position on the timeline, 0 at the start and 1 at the end.
    func fraction(at offset: Int) -> Double {
        guard span > 0 else { return 0 }
        return min(max(Double(offset) / Double(span), 0), 1)
    }

    /// A round's share of the session as a whole percent, e.g. 18.
    func percent(of item: Item) -> Int? {
        placement(of: item).map { Int(($0.width * 100).rounded()) }
    }

    /// The round's own colour, or a steady palette colour for records saved
    /// before History kept colours.
    func color(for item: Item, in record: GameRecord) -> Color? {
        guard item.length != nil else { return nil }
        if let color = record.color(forRound: item.name) { return color }
        guard let index = roundOrder.firstIndex(of: item.name) else { return nil }
        let palette = Theme.ColorValue.timerPalette
        return palette[index % palette.count]
    }
}

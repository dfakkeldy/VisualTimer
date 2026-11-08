import SwiftUI

/// One past session: the short answer first (when, how long, what happened),
/// then the session as one vertical timeline, each round as tall as its share.
struct SessionDetailView: View {

    let record: GameRecord
    @ObservedObject var history: HistoryViewModel
    @ObservedObject var proAccess: ProAccessViewModel
    @Environment(\.dismiss) private var dismiss

    init(record: GameRecord, history: HistoryViewModel, proAccess: ProAccessViewModel) {
        self.record = record
        self._history = ObservedObject(wrappedValue: history)
        self._proAccess = ObservedObject(wrappedValue: proAccess)
        self.sessionTimeline = SessionTimeline(record: record)
    }

    /// Folded once: the record never changes while this screen is open.
    private let sessionTimeline: SessionTimeline

    @State private var showDeleteConfirmation = false
    @State private var showExporter = false
    @State private var requestedProFeature: ProFeature?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summary
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
        let paused = sessionTimeline.items.reduce(0) { $0 + $1.pausedSeconds }
        return VStack(alignment: .leading, spacing: 14) {
            Text("Started \(record.playedAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))")
                .font(.subheadline)
                .foregroundStyle(Theme.ColorValue.textSecondary)

            HStack(alignment: .top, spacing: 28) {
                stat(TimerText.words(Int(session.totalElapsedSeconds)), "total")
                if session.pauseCount > 0 {
                    stat(TimerText.length(paused), session.pauseCount == 1 ? "paused once" : "paused \(session.pauseCount) times")
                }
                if session.skipCount > 0 {
                    stat("\(session.skipCount)", session.skipCount == 1 ? "skipped" : "skipped")
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.ColorValue.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.ColorValue.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Timeline

    private typealias Style = Theme.HistoryTimeline

    /// The session top to bottom on one spine, each round as tall as its share.
    private var timeline: some View {
        let timeline = sessionTimeline
        let items = timeline.items
        let roundIndices = items.indices.filter { items[$0].length != nil }
        let total = max(Double(roundIndices.count) * Style.heightPerRound, Style.minimumTotalHeight)
        let heights = timeline.heights(total: total, minimum: Style.minimumRowHeight)
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Timeline")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                if timeline.hasRounds {
                    Text(legend)
                        .font(.caption)
                        .foregroundStyle(Theme.ColorValue.textTertiary)
                }
            }
            .padding(.bottom, 14)

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                timelineRow(
                    item,
                    height: CGFloat(heights[index] ?? Style.minimumRowHeight),
                    isFirst: index == roundIndices.first,
                    isLast: index == roundIndices.last
                )
            }
        }
    }

    private var legend: String {
        let hasPauses = sessionTimeline.items.contains { !$0.pauses.isEmpty }
        return hasPauses
            ? "Each round is as tall as its share of the session. Darker stretches are pauses."
            : "Each round is as tall as its share of the session."
    }

    @ViewBuilder
    private func timelineRow(_ item: SessionTimeline.Item, height: CGFloat, isFirst: Bool, isLast: Bool) -> some View {
        switch item.outcome {
        case .sessionEnd:
            finishRow(item)
        case .wentBack:
            eventRow(item)
        default:
            roundRow(item, height: height, isFirst: isFirst, isLast: isLast)
        }
    }

    private func roundRow(_ item: SessionTimeline.Item, height: CGFloat, isFirst: Bool, isLast: Bool) -> some View {
        let color = sessionTimeline.color(for: item, in: record) ?? Theme.ColorValue.textTertiary
        let dimmed = item.outcome.dimsRound
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if !item.emoji.isEmpty {
                    Text(item.emoji).accessibilityHidden(true)
                }
                Text(item.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(dimmed ? Theme.ColorValue.textSecondary : Theme.ColorValue.textPrimary)
                Spacer(minLength: 8)
                Text(TimerText.length(item.length ?? 0))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }
            Text(detailLine(item))
                .font(.caption)
                .foregroundStyle(Theme.ColorValue.textTertiary)
        }
        .padding(.bottom, Style.rowBottomPadding)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
        .padding(.leading, Style.spineColumnWidth + Style.spineSpacing)
        .background(alignment: .leading) {
            TimelineSpineSegment(
                color: color,
                pauses: sessionTimeline.pauseFractions(of: item),
                isDimmed: dimmed,
                roundsTop: isFirst,
                roundsBottom: isLast
            )
            .frame(width: Style.spineColumnWidth)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(sessionTimeline.percent(of: item).map { "\($0) percent of the session" } ?? "")
    }

    /// A moment, not a stretch: the spine continues as a hairline past one glyph.
    private func eventRow(_ item: SessionTimeline.Item) -> some View {
        Text("\(item.name) · \(clockText(offset: item.startOffset))")
            .font(.subheadline)
            .foregroundStyle(Theme.ColorValue.textSecondary)
            .padding(.vertical, Style.eventVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, Style.spineColumnWidth + Style.spineSpacing)
            .background(alignment: .leading) {
                TimelineEventMark(symbol: Style.wentBackSymbol)
                    .frame(width: Style.spineColumnWidth)
            }
            .accessibilityElement(children: .combine)
    }

    /// The spine's end: the whole session as the pie it finished on.
    private func finishRow(_ item: SessionTimeline.Item) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Finished")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.ColorValue.textPrimary)
            Text("\(clockText(offset: item.startOffset)) · \(TimerText.words(sessionTimeline.span)) in all")
                .font(.caption)
                .foregroundStyle(Theme.ColorValue.textTertiary)
        }
        .padding(.top, Style.finishTopPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Style.spineColumnWidth + Style.spineSpacing)
        .background(alignment: .topLeading) {
            SequencePie(segments: finishSegments)
                .frame(width: Style.finishPieSize, height: Style.finishPieSize)
                .padding(.top, Style.finishTopPadding)
                .frame(width: Style.spineColumnWidth)
        }
        .accessibilityElement(children: .combine)
    }

    /// "6:34 AM · Cut short · paused 0:45"
    private func detailLine(_ item: SessionTimeline.Item) -> String {
        var parts = [clockText(offset: item.startOffset)]
        if let note = item.outcomeNote { parts.append(note) }
        if item.pauseCount > 0 {
            let time = TimerText.length(item.pausedSeconds)
            parts.append(item.pauseCount == 1 ? "paused \(time)" : "paused \(item.pauseCount)× · \(time)")
        }
        return parts.joined(separator: " · ")
    }

    private func clockText(offset: Int) -> String {
        let start = record.session.events.first?.timestamp ?? record.playedAt
        return start.addingTimeInterval(TimeInterval(offset)).formatted(date: .omitted, time: .shortened)
    }

    private var finishSegments: [SequenceSegment] {
        sessionTimeline.items.enumerated().compactMap { index, item in
            guard let length = item.length, let color = sessionTimeline.color(for: item, in: record) else { return nil }
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
        .padding(.top, Style.deleteTopPadding)
        .accessibilityLabel(Theme.Label.delete)
    }
}

// MARK: - Timeline model

/// Folds a session's raw events into one item per round played.
struct SessionTimeline {
    enum Outcome {
        case finished, skipped, wentBack, restarted, endedEarly, sessionEnd

        /// Rounds that didn't run their course are drawn quieter.
        var dimsRound: Bool { self == .skipped || self == .restarted }

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
        /// What happened to the round, without its pauses: "Skipped", "Cut short".
        var outcomeNote: String? = nil
        /// Every pause pressed in this round, even a repeated one.
        var pauseCount = 0

        var pausedSeconds: Int { pauses.reduce(0) { $0 + $1.count } }
    }

    let items: [Item]
    /// Seconds from the first event to the last: the timeline's full width.
    let span: Int
    /// Palette slots for rounds saved without a colour, skipping saved ones.
    private let fallbackColorIndex: [String: Int]

    /// True when there is at least one round with a length to draw.
    var hasRounds: Bool { span > 0 && items.contains { $0.length != nil } }

    init(record: GameRecord) {
        let events = record.session.events
        guard let origin = events.first?.timestamp else {
            items = []
            span = 0
            fallbackColorIndex = [:]
            return
        }
        func offset(_ date: Date) -> Int { Int(max(date.timeIntervalSince(origin), 0)) }

        var result: [Item] = []
        var open: (name: String, emoji: String, start: Date, pauses: [Range<Int>], pausedAt: Date?, pauseCount: Int)?

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
            if round.pauseCount > 0 { parts.append(round.pauseCount == 1 ? "1 pause" : "\(round.pauseCount) pauses") }
            result.append(Item(
                name: round.name,
                emoji: round.emoji,
                startOffset: offset(round.start),
                length: Int(max(date.timeIntervalSince(round.start), 0)),
                outcome: outcome,
                note: parts.isEmpty ? nil : parts.joined(separator: " · "),
                pauses: round.pauses,
                outcomeNote: note,
                pauseCount: round.pauseCount
            ))
            open = nil
        }

        for event in events {
            switch event {
            case .roundStarted(let name, let emoji, let date):
                close(at: date, .finished)
                open = (name, emoji, date, [], nil, 0)
            case .roundFinished(_, let date):
                close(at: date, .finished)
            case .skipped(_, let date):
                close(at: date, .skipped, note: "Skipped")
            case .doOver(let previous, let date):
                close(at: date, .finished, note: "Cut short")
                result.append(Item(name: "Went back to \(previous)", emoji: "", startOffset: offset(date), length: nil, outcome: .wentBack, note: nil))
            case .restartTimer(_, let date):
                close(at: date, .restarted, note: "Restarted")
            case .paused(let date):
                open?.pauseCount += 1
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
        let paletteCount = Theme.ColorValue.timerPalette.count
        let taken = Set((record.roundColors ?? [:]).values.compactMap { color -> Int? in
            if case .palette(let index) = color { return (0..<paletteCount).contains(index) ? index : 0 }
            return nil
        })
        var free = (0..<paletteCount).filter { !taken.contains($0) }
        if free.isEmpty { free = Array(0..<paletteCount) }
        var fallback: [String: Int] = [:]
        for item in result where item.length != nil
            && record.color(forRound: item.name) == nil
            && fallback[item.name] == nil {
            fallback[item.name] = free[fallback.count % free.count]
        }
        fallbackColorIndex = fallback
    }

    // MARK: Layout

    /// Where a round sits on the timeline, as fractions of the whole session.
    struct Placement: Equatable {
        let start: Double
        let width: Double
    }

    /// Nil for events (went back, finished), which have no length, and for
    /// sessions with no measurable time to divide.
    func placement(of item: Item) -> Placement? {
        guard let length = item.length, span > 0 else { return nil }
        let total = Double(span)
        let start = min(Double(item.startOffset) / total, 1)
        return Placement(start: start, width: min(Double(length) / total, 1 - start))
    }

    /// A position on the timeline, 0 at the start and 1 at the end.
    func fraction(at offset: Int) -> Double {
        guard span > 0 else { return 0 }
        return min(max(Double(offset) / Double(span), 0), 1)
    }

    /// Each round's height on a vertical timeline, by item index: its share
    /// of `total`, never below `minimum`.
    func heights(total: Double, minimum: Double) -> [Int: Double] {
        var result: [Int: Double] = [:]
        for (index, item) in items.enumerated() {
            guard let placement = placement(of: item) else { continue }
            result[index] = max(placement.width * total, minimum)
        }
        return result
    }

    /// Paused stretches as fractions of the round itself, 0 at its start.
    func pauseFractions(of item: Item) -> [ClosedRange<Double>] {
        guard let length = item.length, length > 0 else { return [] }
        let total = Double(length)
        return item.pauses.map { pause in
            let lower = min(max(Double(pause.lowerBound - item.startOffset) / total, 0), 1)
            let upper = min(max(Double(pause.upperBound - item.startOffset) / total, lower), 1)
            return lower...upper
        }
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
        guard let index = fallbackColorIndex[item.name] else { return nil }
        return Theme.ColorValue.timerPalette[index]
    }
}

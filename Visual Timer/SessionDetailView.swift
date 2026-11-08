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
    /// The timeline draws itself downward once, on first appearance.
    @State private var revealed = false
    /// Which picture of the totals this person last chose.
    @AppStorage(SessionTotalsStyle.storageKey) private var totalsStyle = SessionTotalsStyle.pie
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Grows the fixed totals height with Dynamic Type, so larger text never clips.
    @ScaledMetric(relativeTo: .subheadline) private var totalsScale: CGFloat = 1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summary
                if sessionTimeline.totals.count > 1 {
                    totalsSection
                }
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
        return VStack(alignment: .leading, spacing: 12) {
            Text(whenText)
                .font(.subheadline)
                .foregroundStyle(Theme.ColorValue.textSecondary)

            HStack(alignment: .top, spacing: 28) {
                stat(TimerText.units(Int(session.totalElapsedSeconds)), "total")
                if session.pauseCount > 0 {
                    stat(TimerText.units(paused), session.pauseCount == 1 ? "paused once" : "paused \(session.pauseCount) times")
                }
                if session.skipCount > 0 {
                    stat("\(session.skipCount)", "skipped")
                }
            }
        }
    }

    /// "Saturday, Nov 7 · 6:30 – 6:39 AM"
    private var whenText: String {
        let start = record.session.events.first?.timestamp ?? record.playedAt
        let end = start.addingTimeInterval(TimeInterval(sessionTimeline.span))
        let day = start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        let times = (start..<max(end, start)).formatted(.interval.hour().minute())
        return "\(day) · \(times)"
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

    // MARK: - Totals

    private var totalsSection: some View {
        let timeline = sessionTimeline
        let entries = timeline.totals.map { total in
            SessionTotalEntry(
                id: total.name,
                label: [total.emoji, total.name].filter { !$0.isEmpty }.joined(separator: " "),
                color: total.turns.first.flatMap { timeline.color(for: timeline.items[$0], in: record) }
                    ?? Theme.ColorValue.textTertiary,
                seconds: total.seconds,
                turnCount: total.turns.count,
                averageSeconds: total.averageSeconds,
                turns: total.turns.map { index in
                    SessionTotalEntry.Turn(seconds: timeline.items[index].length ?? 0, isDimmed: timeline.items[index].outcome.dimsRound)
                }
            )
        }
        let sum = max(entries.reduce(0) { $0 + $1.seconds }, 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Totals")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                Spacer(minLength: 12)
                Picker("Show totals as", selection: $totalsStyle) {
                    ForEach(SessionTotalsStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            Group {
                switch totalsStyle {
                case .pie:
                    SessionTotalsPie(entries: entries, totalSeconds: sum)
                case .bars:
                    SessionTotalsBars(entries: entries, totalSeconds: sum)
                case .turns:
                    SessionTotalsTurns(entries: entries)
                }
            }
            // One height for all three, so switching never moves the timeline.
            .frame(height: Theme.HistoryTotals.contentHeight(names: entries.count) * totalsScale, alignment: .top)
        }
        .animation(.easeOut(duration: Theme.AnimationValue.stateTransitionDuration), value: totalsStyle)
    }

    // MARK: - Timeline

    private typealias Style = Theme.HistoryTimeline

    /// The session top to bottom on one spine, each round as tall as its share.
    private var timeline: some View {
        let timeline = sessionTimeline
        let items = timeline.items
        let roundIndices = items.indices.filter { items[$0].length != nil }
        let total = max(Double(roundIndices.count) * Style.heightPerRound, Style.minimumTotalHeight)
        let trueHeights = timeline.heights(total: total, minimum: 0)
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Timeline")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                if timeline.hasRounds {
                    legend
                }
            }
            .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if item.length != nil {
                        if let pass = passNumber(at: index, firstRound: roundIndices.first) {
                            passHeader(pass, isFirst: index == roundIndices.first)
                        }
                        roundRow(
                            item,
                            trueHeight: CGFloat(trueHeights[index] ?? 0),
                            isFirst: index == roundIndices.first,
                            wentBackTo: wentBackTarget(after: index, in: items)
                        )
                        .padding(.top, index == roundIndices.first || passNumber(at: index, firstRound: roundIndices.first) != nil ? 0 : Style.turnGap)
                    } else if item.outcome == .sessionEnd {
                        finishRow(item)
                    }
                }
            }
            .mask(alignment: .top) {
                Rectangle().scaleEffect(x: 1, y: revealed ? 1 : 0, anchor: .top)
            }
        }
        .onAppear {
            guard !revealed else { return }
            if reduceMotion {
                revealed = true
            } else {
                withAnimation(.easeOut(duration: Style.revealDuration)) { revealed = true }
            }
        }
    }

    /// "Round 2" when a new pass through the sequence starts at this item;
    /// nil when the sequence ran only once.
    private func passNumber(at index: Int, firstRound: Int?) -> Int? {
        let starts = sessionTimeline.passStarts
        guard !starts.isEmpty else { return nil }
        if index == firstRound { return 1 }
        return starts.firstIndex(of: index).map { $0 + 2 }
    }

    private func passHeader(_ pass: Int, isFirst: Bool) -> some View {
        Text("Round \(pass) of \(sessionTimeline.passStarts.count + 1)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.ColorValue.textSecondary)
            .padding(.top, isFirst ? 0 : Style.passGap)
            .padding(.bottom, Style.passLabelBottomPadding)
            .accessibilityAddTraits(.isHeader)
    }

    /// The name of the round someone went back to, when that happened right
    /// after this round.
    private func wentBackTarget(after index: Int, in items: [SessionTimeline.Item]) -> String? {
        let next = index + 1
        guard items.indices.contains(next), items[next].outcome == .wentBack else { return nil }
        return items[next].wentBackTo
    }

    private var legend: some View {
        let hasPauses = sessionTimeline.items.contains { !$0.pauses.isEmpty }
        let hasFaded = sessionTimeline.items.contains { $0.outcome.dimsRound }
        var key = hasPauses ? "Height is time, pauses included. Hatched is paused." : "Height is time."
        if hasFaded { key += " Faded was skipped or restarted." }
        return HStack(alignment: .center, spacing: 8) {
            TimelineSpineSegment(
                color: Theme.ColorValue.textSecondary,
                trueHeight: Style.legendSwatchHeight,
                pauses: hasPauses ? [0.35...0.7] : [],
                isDimmed: false,
                roundsTop: true,
                roundsBottom: true
            )
            .frame(width: Style.spineColumnWidth, height: Style.legendSwatchHeight)
            Text(key)
                .font(.caption)
                .foregroundStyle(Theme.ColorValue.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func roundRow(_ item: SessionTimeline.Item, trueHeight: CGFloat, isFirst: Bool, wentBackTo: String?) -> some View {
        let color = sessionTimeline.color(for: item, in: record) ?? Theme.ColorValue.textTertiary
        let dimmed = item.outcome.dimsRound
        let pauses = sessionTimeline.pauseFractions(of: item)
        let rowHeight = max(trueHeight, CGFloat(Style.minimumRowHeight) + (wentBackTo == nil ? 0 : Style.wentBackLabelHeight))
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if !item.emoji.isEmpty {
                    Text(item.emoji).accessibilityHidden(true)
                }
                Text(item.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(dimmed ? Theme.ColorValue.textSecondary : Theme.ColorValue.textPrimary)
                Text(TimerText.units(item.length ?? 0))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }
            Text(detailLine(item, wentBackTo: wentBackTo))
                .font(.caption)
                .foregroundStyle(Theme.ColorValue.textSecondary)
        }
        .padding(.top, Style.rowTopPadding)
        .padding(.leading, Style.labelInset)
        .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            pauseLabels(item, pauses: pauses, trueHeight: trueHeight)
        }
        .overlay(alignment: .bottomLeading) {
            // The moment it happened: the foot of this turn, beside the spine.
            if let wentBackTo {
                Label("back to \(wentBackTo)", systemImage: Style.wentBackSymbol)
                    .font(.caption)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                    .padding(.leading, Style.labelInset)
                    .accessibilityHidden(true)
            }
        }
        .padding(.leading, Style.spineColumnWidth)
        .background(alignment: .leading) {
            TimelineSpineSegment(
                color: color,
                trueHeight: trueHeight,
                pauses: pauses,
                isDimmed: dimmed,
                roundsTop: true,
                roundsBottom: true
            )
            .frame(width: Style.spineColumnWidth)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(sessionTimeline.percent(of: item).map { "\($0) percent of the session" } ?? "")
        .accessibilityHint(wentBackTo.map { "Then went back to \($0)." } ?? "")
    }

    /// "paused 45s" beside each hatched band, never over the round's name.
    private func pauseLabels(_ item: SessionTimeline.Item, pauses: [ClosedRange<Double>], trueHeight: CGFloat) -> some View {
        let durations = item.pauses.map { $0.count }
        return ZStack(alignment: .topLeading) {
            ForEach(Array(pauses.enumerated()), id: \.offset) { index, pause in
                let middle: CGFloat = trueHeight * CGFloat((pause.lowerBound + pause.upperBound) / 2)
                Text("paused \(TimerText.units(durations[index]))")
                    .font(.caption)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                    .offset(x: Style.labelInset, y: max(middle - Style.pauseLabelHalfHeight, Style.pauseLabelMinimumY))
            }
        }
        .accessibilityHidden(true)
    }

    /// The spine's end: one quiet mark, no louder than the turns before it.
    private func finishRow(_ item: SessionTimeline.Item) -> some View {
        let endedEarly = sessionTimeline.items.contains { $0.outcome == .endedEarly }
        let rest = "\(clockText(offset: item.startOffset)) · \(TimerText.units(sessionTimeline.span))"
        return (Text(endedEarly ? "Ended" : "Finished").foregroundStyle(Theme.ColorValue.textPrimary)
                + Text(" · \(rest)").foregroundStyle(Theme.ColorValue.textSecondary))
            .font(.body)
            .frame(minHeight: Style.finishDiscSize)
            .padding(.leading, Style.labelInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, Style.spineColumnWidth)
            .background(alignment: .topLeading) {
                TimelineFinishMark(endedEarly: endedEarly)
                    .frame(width: Style.finishDiscSize, height: Style.finishDiscSize)
                    .frame(width: Style.spineColumnWidth)
            }
            .accessibilityElement(children: .combine)
            .padding(.top, Style.turnGap)
    }

    /// "6:32 AM · Cut short". A went-back is marked where it happened instead.
    private func detailLine(_ item: SessionTimeline.Item, wentBackTo: String?) -> String {
        var parts = [clockText(offset: item.startOffset)]
        if let note = item.outcomeNote { parts.append(note) }
        return parts.joined(separator: " · ")
    }

    private func clockText(offset: Int) -> String {
        let start = record.session.events.first?.timestamp ?? record.playedAt
        return start.addingTimeInterval(TimeInterval(offset)).formatted(date: .omitted, time: .shortened)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete session", systemImage: Theme.Symbol.delete)
                .font(.subheadline)
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

        /// For a "went back" moment, the round gone back to.
        var wentBackTo: String? = nil

        var pausedSeconds: Int { pauses.reduce(0) { $0 + $1.count } }
    }

    let items: [Item]
    /// Seconds from the first event to the last: the timeline's full width.
    let span: Int
    /// Item indices where a new pass through the sequence begins: the first
    /// round's name comes up again (not as a "went back" redo). Empty when
    /// the sequence ran once.
    let passStarts: [Int]

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
            passStarts = []
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
                result.append(Item(name: "Went back to \(previous)", emoji: "", startOffset: offset(date), length: nil, outcome: .wentBack, note: nil, wentBackTo: previous))
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

        var starts: [Int] = []
        let roundIndices = result.indices.filter { result[$0].length != nil }
        if let first = roundIndices.first {
            for index in roundIndices.dropFirst()
            where result[index].name == result[first].name && result[index - 1].outcome != .wentBack {
                starts.append(index)
            }
        }
        passStarts = starts
    }

    // MARK: Totals

    /// One name's share of the session: every turn it took, added up.
    struct Total: Identifiable, Equatable {
        let name: String
        let emoji: String
        let seconds: Int
        /// Indices into `items`, in the order the turns ran.
        let turns: [Int]
        var id: String { name }
        var averageSeconds: Int { turns.isEmpty ? 0 : seconds / turns.count }
    }

    /// Each name once, in the order it first ran.
    var totals: [Total] {
        var order: [String] = []
        var byName: [String: (emoji: String, seconds: Int, turns: [Int])] = [:]
        for (index, item) in items.enumerated() {
            guard let length = item.length else { continue }
            if byName[item.name] == nil {
                order.append(item.name)
                byName[item.name] = (item.emoji, 0, [])
            }
            byName[item.name]?.seconds += length
            byName[item.name]?.turns.append(index)
        }
        return order.compactMap { name in
            byName[name].map { Total(name: name, emoji: $0.emoji, seconds: $0.seconds, turns: $0.turns) }
        }
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

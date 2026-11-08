import SwiftUI

/// One past session: the short answer first (when, how long, what happened),
/// then one row per round on a timeline.
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

    private var timeline: some View {
        let items = SessionTimeline(record: record).items
        return VStack(alignment: .leading, spacing: 0) {
            Text("Rounds")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ColorValue.textSecondary)
                .padding(.bottom, 10)

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Group {
                            if let color = record.color(forRound: item.name) {
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

                    VStack(alignment: .leading, spacing: 2) {
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
                        if let note = item.note {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(Theme.ColorValue.textTertiary)
                        }
                    }
                    .padding(.bottom, 16)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var finishSegments: [SequenceSegment] {
        SessionTimeline(record: record).items.enumerated().compactMap { index, item in
            guard let length = item.length, let color = record.color(forRound: item.name) else { return nil }
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
    }

    let items: [Item]

    init(record: GameRecord) {
        let events = record.session.events
        guard let origin = events.first?.timestamp else {
            items = []
            return
        }
        func offset(_ date: Date) -> Int { Int(max(date.timeIntervalSince(origin), 0)) }

        var result: [Item] = []
        var open: (name: String, emoji: String, start: Date, pauses: Int)?

        func close(at date: Date, _ outcome: Outcome, note: String? = nil) {
            guard let round = open else { return }
            var parts: [String] = []
            if let note { parts.append(note) }
            if round.pauses > 0 { parts.append(round.pauses == 1 ? "1 pause" : "\(round.pauses) pauses") }
            result.append(Item(
                name: round.name,
                emoji: round.emoji,
                startOffset: offset(round.start),
                length: Int(max(date.timeIntervalSince(round.start), 0)),
                outcome: outcome,
                note: parts.isEmpty ? nil : parts.joined(separator: " · ")
            ))
            open = nil
        }

        for event in events {
            switch event {
            case .roundStarted(let name, let emoji, let date):
                close(at: date, .finished)
                open = (name, emoji, date, 0)
            case .roundFinished(_, let date):
                close(at: date, .finished)
            case .skipped(_, let date):
                close(at: date, .skipped, note: "Skipped")
            case .doOver(let previous, let date):
                close(at: date, .finished, note: "Cut short")
                result.append(Item(name: "↩︎ Back to \(previous)", emoji: "", startOffset: offset(date), length: nil, outcome: .wentBack, note: nil))
            case .restartTimer(_, let date):
                close(at: date, .restarted, note: "Restarted")
            case .paused:
                open?.pauses += 1
            case .resumed, .gameStarted:
                break
            case .gameEnded(let date):
                close(at: date, .endedEarly, note: "Session ended here")
                result.append(Item(name: "Finished", emoji: "", startOffset: offset(date), length: nil, outcome: .sessionEnd, note: nil))
            }
        }
        items = result
    }
}

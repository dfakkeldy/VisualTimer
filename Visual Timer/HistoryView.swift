import SwiftUI

struct HistoryView: View {

    @ObservedObject var history: HistoryViewModel
    @ObservedObject var proAccess: ProAccessViewModel
    var onBrowseTemplates: () -> Void = {}

    init(history: HistoryViewModel, proAccess: ProAccessViewModel, onBrowseTemplates: @escaping () -> Void = {}) {
        self.history = history
        self.proAccess = proAccess
        self.onBrowseTemplates = onBrowseTemplates
    }

    @State private var deleteTargets: [GameRecord] = []
    @State private var requestedProFeature: ProFeature?
    @State private var showDeleteConfirmation = false

    private var visibleRecords: [GameRecord] {
        HistoryAccessPolicy.visibleRecords(history.records, isProUnlocked: proAccess.isProUnlocked)
    }

    var body: some View {
        NavigationStack {
            Group {
                if history.records.isEmpty {
                    emptyState
                } else {
                    recordsList
                }
            }
            .background(Theme.ColorValue.appBackground)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                history.loadRecords()
            }
            .alert(deleteConfirmationTitle, isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteConfirmedRecords()
                }
                Button("Cancel", role: .cancel) {
                    clearDeleteTargets()
                }
            } message: {
                Text(deleteConfirmationMessage)
            }
            .sheet(item: $requestedProFeature) { feature in
                ProPaywallView(feature: feature, proAccess: proAccess)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            GhostDial()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text("Your finished sessions appear here")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ColorValue.textPrimary)
                .multilineTextAlignment(.center)
            Text("Finished and ended sessions are kept. Quick timers aren't.")
                .font(.subheadline)
                .foregroundStyle(Theme.ColorValue.textSecondary)
                .multilineTextAlignment(.center)
            GlassCapsuleButton(title: "Choose a template", systemImage: Theme.Symbol.templates, prominent: true) {
                onBrowseTemplates()
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 140)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Records List

    private var recordsList: some View {
        List {
            if HistoryAccessPolicy.isLimited(records: history.records, isProUnlocked: proAccess.isProUnlocked) {
                // The free rule sits first, where it can't hide under the tab bar.
                Section {
                    Button {
                        requestedProFeature = .fullHistory
                    } label: {
                        HStack(spacing: 8) {
                            Text(hiddenRecordsText)
                                .font(.footnote)
                                .foregroundStyle(Theme.ColorValue.textSecondary)
                            Spacer(minLength: 8)
                            Text("Unlock ›")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.ColorValue.selectionAccent)
                        }
                    }
                    .listRowBackground(Theme.ColorValue.surface)
                    .accessibilityLabel("Unlock full history. \(hiddenRecordsText)")
                }
            }

            ForEach(dayGroups, id: \.title) { group in
                Section {
                    ForEach(group.records) { record in
                        NavigationLink {
                            SessionDetailView(record: record, history: history, proAccess: proAccess)
                        } label: {
                            recordRow(record)
                        }
                        .listRowBackground(Theme.ColorValue.surface)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                requestDelete([record])
                            } label: {
                                Label("Delete", systemImage: Theme.Symbol.delete)
                            }
                        }
                    }
                } header: {
                    Text(group.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.ColorValue.textSecondary)
                        .textCase(nil)
                }
            }

        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 24, for: .scrollContent)
    }

    private var hiddenRecordsText: String {
        let hidden = history.records.count - visibleRecords.count
        let noun = hidden == 1 ? "older session" : "older sessions"
        return "Showing your \(HistoryAccessPolicy.freeRecordLimit) most recent · \(hidden) \(noun) kept"
    }

    private struct DayGroup {
        let title: String
        let records: [GameRecord]
    }

    private var dayGroups: [DayGroup] {
        let calendar = Calendar.current
        var groups: [DayGroup] = []
        for record in visibleRecords {
            let title: String
            if calendar.isDateInToday(record.playedAt) {
                title = "Today"
            } else if calendar.isDateInYesterday(record.playedAt) {
                title = "Yesterday"
            } else if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: record.playedAt), to: calendar.startOfDay(for: Date())).day, days < 7 {
                title = "This week"
            } else {
                title = "Earlier"
            }
            if let last = groups.last, last.title == title {
                groups[groups.count - 1] = DayGroup(title: title, records: last.records + [record])
            } else {
                groups.append(DayGroup(title: title, records: [record]))
            }
        }
        return groups
    }

    private func recordRow(_ record: GameRecord) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(record.gameTitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ColorValue.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(dateText(record.playedAt))
                    .font(.caption)
                    .foregroundStyle(Theme.ColorValue.textTertiary)
            }

            let segments = colorSegments(record)
            if !segments.isEmpty {
                SequenceRibbon(segments: segments, height: 4)
                    .padding(.vertical, 2)
            }

            Text(summaryLine(record))
                .font(.caption)
                .foregroundStyle(Theme.ColorValue.textSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// The rounds as they ran, in their colours and sized by time.
    private func colorSegments(_ record: GameRecord) -> [SequenceSegment] {
        guard record.roundColors != nil else { return [] }
        return SessionTimeline(record: record).items.enumerated().compactMap { index, item in
            guard let length = item.length, let color = record.color(forRound: item.name) else { return nil }
            return SequenceSegment(id: index, color: color, seconds: max(length, 1))
        }
    }

    /// The session's rounds as their emoji, in order, each once.
    private func emojiStrip(_ record: GameRecord) -> String {
        var seen: [String] = []
        for event in record.session.events {
            if case .roundStarted(_, let emoji, _) = event, !emoji.isEmpty, !seen.contains(emoji) {
                seen.append(emoji)
            }
        }
        return seen.prefix(6).joined()
    }

    private func summaryLine(_ record: GameRecord) -> String {
        let session = record.session
        var parts: [String] = [TimerText.words(Int(session.totalElapsedSeconds))]
        parts.append(TurnTimerCountText.label(for: session.roundCount, singular: "round"))
        if session.skipCount > 0 { parts.append(TurnTimerCountText.label(for: session.skipCount, singular: "skip")) }
        if session.doOverCount > 0 { parts.append("\(session.doOverCount) back") }
        return parts.joined(separator: " · ")
    }

    private func dateText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) || calendar.isDateInYesterday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var deleteConfirmationTitle: String {
        deleteTargets.count == 1 ? "Delete Session" : "Delete Sessions"
    }

    private var deleteConfirmationMessage: String {
        if let record = deleteTargets.first, deleteTargets.count == 1 {
            return "Delete \"\(record.gameTitle)\" from history? This cannot be undone."
        }
        return "Delete \(deleteTargets.count) sessions from history? This cannot be undone."
    }

    private func requestDelete(_ records: [GameRecord]) {
        guard !records.isEmpty else { return }
        deleteTargets = records
        showDeleteConfirmation = true
    }

    private func deleteConfirmedRecords() {
        for record in deleteTargets {
            history.deleteRecord(id: record.id)
        }
        clearDeleteTargets()
    }

    private func clearDeleteTargets() {
        deleteTargets = []
    }


}

/// The empty dial: a closed hairline rim, three uneven seams from twelve,
/// and one faint wedge of colour. A dial waiting to fill, never a spinner.
private struct GhostDial: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 1
            let origin = Theme.Rotation.trimOriginOffset
            var wedge = Path()
            wedge.move(to: center)
            wedge.addArc(center: center, radius: radius, startAngle: .degrees(origin), endAngle: .degrees(origin + 110), clockwise: false)
            wedge.closeSubpath()
            context.fill(wedge, with: .color(Theme.ColorValue.timerPalette[7].opacity(0.28)))
            for angle in [0.0, 110, 250] {
                var seam = Path()
                seam.move(to: center)
                let radians = (origin + angle) * .pi / 180
                seam.addLine(to: CGPoint(x: center.x + radius * cos(radians), y: center.y + radius * sin(radians)))
                context.stroke(seam, with: .color(Theme.ColorValue.textTertiary), lineWidth: 1)
            }
            context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                           with: .color(Theme.ColorValue.textTertiary), lineWidth: 1)
        }
    }
}

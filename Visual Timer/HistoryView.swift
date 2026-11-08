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
            Circle()
                .strokeBorder(Theme.ColorValue.textTertiary, style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                .frame(width: 88, height: 88)
                .accessibilityHidden(true)
            Text("Your finished sessions appear here")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ColorValue.textPrimary)
                .multilineTextAlignment(.center)
            Text("Run a template from start to finish, or end it early, and it's kept here. Quick timers aren't logged.")
                .font(.subheadline)
                .foregroundStyle(Theme.ColorValue.textSecondary)
                .multilineTextAlignment(.center)
            GlassCapsuleButton(title: "Choose a template", systemImage: Theme.Symbol.templates, prominent: true) {
                onBrowseTemplates()
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Records List

    private var recordsList: some View {
        List {
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

            if HistoryAccessPolicy.isLimited(records: history.records, isProUnlocked: proAccess.isProUnlocked) {
                Section {
                    Button {
                        requestedProFeature = .fullHistory
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Unlock full history", systemImage: Theme.Symbol.proUnlock)
                                .font(.body.weight(.medium))
                            Text(hiddenRecordsText)
                                .font(.caption)
                                .foregroundStyle(Theme.ColorValue.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var hiddenRecordsText: String {
        let hidden = history.records.count - visibleRecords.count
        let noun = hidden == 1 ? "older session is" : "older sessions are"
        return "\(hidden) \(noun) kept on this iPhone. Free shows your \(HistoryAccessPolicy.freeRecordLimit) most recent."
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

            HStack(spacing: 8) {
                let emoji = emojiStrip(record)
                if !emoji.isEmpty {
                    Text(emoji)
                        .font(.caption)
                        .accessibilityHidden(true)
                }
                Text(summaryLine(record))
                    .font(.caption)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
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
        if session.doOverCount > 0 { parts.append(TurnTimerCountText.label(for: session.doOverCount, singular: "do-over")) }
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

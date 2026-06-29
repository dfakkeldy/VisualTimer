import SwiftUI

struct HistoryView: View {

    @ObservedObject var history: HistoryViewModel
    @ObservedObject var proAccess: ProAccessViewModel

    init(history: HistoryViewModel, proAccess: ProAccessViewModel) {
        self.history = history
        self.proAccess = proAccess
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
        VStack(spacing: 12) {
            Image(systemName: Theme.Symbol.history)
                .font(.system(size: 48))
                .foregroundStyle(Theme.ColorValue.textSecondary)
            Text("No sessions yet")
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.ColorValue.textSecondary)
            Text("Complete a session to see it here.")
                .font(.subheadline)
                .foregroundStyle(Theme.ColorValue.textSecondary.opacity(0.7))
        }
    }

    // MARK: - Records List

    private var recordsList: some View {
        List {
            ForEach(visibleRecords) { record in
                NavigationLink {
                    SessionDetailView(record: record, history: history, proAccess: proAccess)
                } label: {
                    recordRow(record)
                }
                .listRowBackground(Theme.ColorValue.circleBackground)
            }
            .onDelete { offsets in
                let recordsToDelete = offsets.compactMap { index in
                    visibleRecords.indices.contains(index) ? visibleRecords[index] : nil
                }
                requestDelete(recordsToDelete)
            }

            if HistoryAccessPolicy.isLimited(records: history.records, isProUnlocked: proAccess.isProUnlocked) {
                Button {
                    requestedProFeature = .fullHistory
                } label: {
                    Label("Unlock full history", systemImage: Theme.Symbol.proUnlock)
                }
                .listRowBackground(Theme.ColorValue.circleBackground)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func recordRow(_ record: GameRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.gameTitle)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.ColorValue.textPrimary)

            Text(summaryLine(record))
                .font(.caption)
                .foregroundStyle(Theme.ColorValue.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private func summaryLine(_ record: GameRecord) -> String {
        let session = record.session
        let elapsed = formatElapsed(session.totalElapsedSeconds)
        var parts: [String] = []
        parts.append(elapsed)
        parts.append(TurnTimerCountText.label(for: session.roundCount, singular: "round"))
        if session.skipCount > 0 { parts.append(TurnTimerCountText.label(for: session.skipCount, singular: "skip")) }
        if session.doOverCount > 0 { parts.append(TurnTimerCountText.label(for: session.doOverCount, singular: "do-over")) }
        parts.append(playedAtFormatter.string(from: record.playedAt))
        return parts.joined(separator: " · ")
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

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private var playedAtFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}

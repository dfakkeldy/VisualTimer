import SwiftUI

struct HistoryView: View {

    @ObservedObject var history: HistoryViewModel
    @ObservedObject var proAccess: ProAccessViewModel

    init(history: HistoryViewModel, proAccess: ProAccessViewModel) {
        self.history = history
        self.proAccess = proAccess
    }

    @State private var deleteTarget: GameRecord?
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
            .alert("Delete Session", isPresented: $showDeleteConfirmation, presenting: deleteTarget) { record in
                Button("Delete", role: .destructive) {
                    history.deleteRecord(id: record.id)
                }
                Button("Cancel", role: .cancel) {}
            } message: { record in
                Text("Delete \"\(record.gameTitle)\" from history? This cannot be undone.")
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
                for record in recordsToDelete {
                    history.deleteRecord(id: record.id)
                }
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
        parts.append("\(session.roundCount) rounds")
        if session.skipCount > 0 { parts.append("\(session.skipCount) skips") }
        if session.doOverCount > 0 { parts.append("\(session.doOverCount) do-overs") }
        parts.append(playedAtFormatter.string(from: record.playedAt))
        return parts.joined(separator: " · ")
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

import SwiftUI

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
            VStack(alignment: .leading, spacing: 0) {
                // Header
                headerSection
                    .padding(.horizontal, Theme.Dimension.screenHorizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider()
                    .background(Theme.ColorValue.textSecondary.opacity(0.3))
                    .padding(.horizontal, Theme.Dimension.screenHorizontalPadding)

                // Event timeline
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(record.session.events.enumerated()), id: \.offset) { _, event in
                        eventRow(event)
                    }
                }
                .padding(.horizontal, Theme.Dimension.screenHorizontalPadding)
                .padding(.vertical, 12)

                Divider()
                    .background(Theme.ColorValue.textSecondary.opacity(0.3))
                    .padding(.horizontal, Theme.Dimension.screenHorizontalPadding)

                // Footer stats
                footerSection
                    .padding(.horizontal, Theme.Dimension.screenHorizontalPadding)
                    .padding(.vertical, 16)
            }
        }
        .background(Theme.ColorValue.appBackground)
        .navigationTitle(record.gameTitle)
        .navigationBarTitleDisplayMode(.inline)
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
            ToolbarItem(placement: .destructiveAction) {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: Theme.Symbol.delete)
                }
                .accessibilityLabel(Theme.Label.delete)
            }
        }
        .alert("Delete Session", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                history.deleteRecord(id: record.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete \"\(record.gameTitle)\" from history?")
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

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.gameTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.ColorValue.textPrimary)
            Text("Played \(playedAtFull.string(from: record.playedAt))")
                .font(.subheadline)
                .foregroundStyle(Theme.ColorValue.textSecondary)
        }
    }

    // MARK: - Event Rows

    private func eventRow(_ event: SessionEvent) -> some View {
        HStack(spacing: 12) {
            // Elapsed timestamp
            Text(formatTimestamp(event))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.ColorValue.textSecondary)
                .frame(width: 60, alignment: .trailing)

            // Icon
            Image(systemName: event.iconName)
                .font(.caption)
                .foregroundStyle(eventIconColor(event))
                .frame(width: 20)

            // Label
            Text(event.label)
                .font(.caption)
                .foregroundStyle(Theme.ColorValue.textPrimary)

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func eventIconColor(_ event: SessionEvent) -> Color {
        switch event {
        case .gameStarted: return .green
        case .roundStarted: return .blue
        case .roundFinished: return .orange
        case .skipped: return .yellow
        case .doOver: return .purple
        case .restartTimer: return .mint
        case .paused: return .gray
        case .resumed: return .green
        case .gameEnded: return .red
        }
    }

    private func formatTimestamp(_ event: SessionEvent) -> String {
        guard let first = record.session.events.first?.timestamp else { return "0:00" }
        let delta = event.timestamp.timeIntervalSince(first)
        let total = Int(max(delta, 0))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Footer

    private var footerSection: some View {
        let session = record.session
        return VStack(alignment: .leading, spacing: 6) {
            Text("Summary")
                .font(.headline)
                .foregroundStyle(Theme.ColorValue.textPrimary)
            Text("Total time: \(formatElapsed(session.totalElapsedSeconds))")
                .font(.subheadline)
                .foregroundStyle(Theme.ColorValue.textSecondary)
            Text([
                TurnTimerCountText.label(for: session.roundCount, singular: "round"),
                TurnTimerCountText.label(for: session.skipCount, singular: "skip"),
                TurnTimerCountText.label(for: session.doOverCount, singular: "do-over"),
                TurnTimerCountText.label(for: session.pauseCount, singular: "pause"),
            ].joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(Theme.ColorValue.textSecondary)
        }
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private var playedAtFull: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

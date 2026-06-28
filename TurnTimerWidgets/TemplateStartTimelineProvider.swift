import Foundation
import WidgetKit

struct TemplateStartEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetTemplateSnapshot
}

struct TemplateStartTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TemplateStartEntry {
        TemplateStartEntry(date: Date(), snapshot: .gameNightFallback)
    }

    func snapshot(for configuration: TemplateWidgetIntent, in context: Context) async -> TemplateStartEntry {
        TemplateStartEntry(date: Date(), snapshot: selectedSnapshot(for: configuration))
    }

    func timeline(for configuration: TemplateWidgetIntent, in context: Context) async -> Timeline<TemplateStartEntry> {
        let entry = TemplateStartEntry(date: Date(), snapshot: selectedSnapshot(for: configuration))
        let refreshDate = Date().addingTimeInterval(30 * 60)
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func selectedSnapshot(for configuration: TemplateWidgetIntent) -> WidgetTemplateSnapshot {
        let snapshots = Self.availableSnapshots()
        guard !snapshots.isEmpty else { return .proLocked }

        if let selectedID = configuration.template?.id,
           let selected = snapshots.first(where: { $0.id == selectedID }) {
            return selected
        }

        return snapshots.first(where: { $0.id == WidgetTemplateSnapshot.gameNightFallback.id })
            ?? snapshots.first(where: { $0.source != .locked })
            ?? snapshots.first
            ?? .proLocked
    }

    static func availableSnapshots() -> [WidgetTemplateSnapshot] {
        (try? WidgetSnapshotStore().readSnapshots()) ?? []
    }
}

extension WidgetTemplateSnapshot {
    nonisolated static var gameNightFallback: WidgetTemplateSnapshot {
        WidgetTemplateSnapshot(
            id: "game-night",
            title: "Game Night",
            subtitle: "Player turns plus a table timeout.",
            source: .starter,
            templateID: nil,
            starterID: "game-night",
            totalSeconds: 300,
            roundCount: 4,
            modifiedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

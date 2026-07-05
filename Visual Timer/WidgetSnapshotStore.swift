import Foundation

enum WidgetSnapshotStoreError: Error, Equatable {
    case missingAppGroupContainer
}

struct WidgetSnapshotStore {
    static let fileName = "WidgetTemplates.json"

    private let containerURLProvider: () -> URL?
    private let fileManager: FileManager
    private let dateProvider: () -> Date

    init(
        containerURLProvider: @escaping () -> URL? = { SharedAppGroup.containerURL() },
        fileManager: FileManager = .default,
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        self.containerURLProvider = containerURLProvider
        self.fileManager = fileManager
        self.dateProvider = dateProvider
    }

    func writeSnapshots(savedTemplates: [SavedTemplate], isProUnlocked: Bool) throws {
        let url = try snapshotsURL()
        let snapshots = isProUnlocked
            ? starterSnapshots() + savedTemplates.map(savedSnapshot)
            : [WidgetTemplateSnapshot.proLocked]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshots)

        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: [.atomic])
    }

    func readSnapshots() throws -> [WidgetTemplateSnapshot] {
        let url = try snapshotsURL()
        guard fileManager.fileExists(atPath: url.path) else { return [] }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([WidgetTemplateSnapshot].self, from: data)
    }

    private func snapshotsURL() throws -> URL {
        guard let containerURL = containerURLProvider() else {
            throw WidgetSnapshotStoreError.missingAppGroupContainer
        }
        return containerURL.appendingPathComponent(Self.fileName)
    }

    private func starterSnapshots() -> [WidgetTemplateSnapshot] {
        let modifiedAt = dateProvider()
        return StarterTemplateLibrary.templates.map { template in
            WidgetTemplateSnapshot(
                id: template.id,
                title: template.title,
                subtitle: template.subtitle,
                source: .starter,
                templateID: nil,
                starterID: template.id,
                totalSeconds: totalSeconds(for: template.game),
                roundCount: template.game.activeRounds.count,
                modifiedAt: modifiedAt
            )
        }
    }

    private func savedSnapshot(_ template: SavedTemplate) -> WidgetTemplateSnapshot {
        WidgetTemplateSnapshot(
            id: template.id.uuidString,
            title: template.title,
            subtitle: template.subtitle,
            source: .saved,
            templateID: template.id,
            starterID: nil,
            totalSeconds: template.totalSeconds,
            roundCount: template.roundCount,
            modifiedAt: template.modifiedAt
        )
    }

    private func totalSeconds(for game: GameSequence) -> Int {
        let sequenceSeconds = game.activeRounds.reduce(0) { total, round in
            total + round.durationSeconds
        }
        return sequenceSeconds * game.roundCount
    }
}

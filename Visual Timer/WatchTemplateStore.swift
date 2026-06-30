import Foundation

enum WatchTemplateStoreError: Error, Equatable {
    case missingAppGroupContainer
}

/// Full-payload template snapshots written by the iOS app into the shared
/// App Group so the watchOS app can reconstruct and play back saved templates.
///
/// Unlike `WidgetTemplateStore` (metadata only), each entry carries the
/// complete `GameSequence`, which is enough to drive `GameViewModel` playback
/// on the watch without resolving a `templateID` against iOS-only storage.
struct WatchTemplate: Codable, Equatable, Identifiable {
    var templateID: UUID
    var title: String
    var game: GameSequence
    var modifiedAt: Date

    var id: UUID { templateID }
}

struct WatchTemplateStore {
    static let fileName = "WatchTemplates.json"

    private let containerURLProvider: () -> URL?
    private let fileManager: FileManager

    init(
        containerURLProvider: @escaping () -> URL? = { SharedAppGroup.containerURL() },
        fileManager: FileManager = .default
    ) {
        self.containerURLProvider = containerURLProvider
        self.fileManager = fileManager
    }

    /// Writes the given saved templates' full games into the App Group.
    /// Pass an empty array when the feature is disabled or Pro is locked so
    /// the watch sees no saved templates.
    func write(templates: [WatchTemplate]) throws {
        let url = try storeURL()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(templates)

        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: [.atomic])
    }

    /// Reads saved templates published by the iOS app. Returns an empty array
    /// when the file is missing (no iOS app has published yet, or not Pro).
    func read() throws -> [WatchTemplate] {
        let url = try storeURL()
        guard fileManager.fileExists(atPath: url.path) else { return [] }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([WatchTemplate].self, from: data)
    }

    private func storeURL() throws -> URL {
        guard let containerURL = containerURLProvider() else {
            throw WatchTemplateStoreError.missingAppGroupContainer
        }
        return containerURL.appendingPathComponent(Self.fileName)
    }
}

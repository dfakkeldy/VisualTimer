import Foundation

enum WatchTemplateStoreError: Error, Equatable {
    case missingAppGroupContainer
}

/// Full-payload template snapshots. App Group storage is local to each device;
/// WatchConnectivity transfers snapshots from iOS to watchOS.
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
    static let contextKey = "turnTimerTemplateSnapshot"

    private struct Snapshot: Codable {
        var revision: UInt64
        var templates: [WatchTemplate]
    }

    static func applicationContext(
        for templates: [WatchTemplate],
        revision: UInt64 = UInt64(Date().timeIntervalSince1970 * 1_000_000)
    ) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return [contextKey: try encoder.encode(Snapshot(revision: revision, templates: templates))]
    }

    /// Validate before replacing the last durable snapshot. Revisions prevent a
    /// delayed large-file transfer from restoring templates after Pro revocation.
    @discardableResult
    func applyApplicationContext(_ context: [String: Any]) throws -> Bool {
        guard let data = context[Self.contextKey] as? Data else { return false }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(Snapshot.self, from: data)
        let url = try storeURL()
        if let previousData = try? Data(contentsOf: url),
           let previous = try? decoder.decode(Snapshot.self, from: previousData),
           snapshot.revision <= previous.revision {
            return false
        }
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return true
    }

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

    /// Reads this device's durable snapshot, including the prior array format.
    /// Returns an empty array until a snapshot is received or when Pro is locked.
    func read() throws -> [WatchTemplate] {
        let url = try storeURL()
        guard fileManager.fileExists(atPath: url.path) else { return [] }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let snapshot = try? decoder.decode(Snapshot.self, from: data) {
            return snapshot.templates
        }
        return try decoder.decode([WatchTemplate].self, from: data)
    }

    private func storeURL() throws -> URL {
        guard let containerURL = containerURLProvider() else {
            throw WatchTemplateStoreError.missingAppGroupContainer
        }
        return containerURL.appendingPathComponent(Self.fileName)
    }
}

import Foundation

// MARK: - Game Session

struct GameSession: Codable {
    var events: [SessionEvent] = []

    var totalElapsedSeconds: TimeInterval {
        guard let first = events.first?.timestamp,
              let last = events.last?.timestamp else { return 0 }
        return last.timeIntervalSince(first)
    }

    var roundCount: Int {
        events.filter {
            if case .roundStarted = $0 { return true }
            return false
        }.count
    }

    var skipCount: Int {
        events.filter {
            if case .skipped = $0 { return true }
            return false
        }.count
    }

    var doOverCount: Int {
        events.filter {
            if case .doOver = $0 { return true }
            return false
        }.count
    }

    var pauseCount: Int {
        events.filter {
            if case .paused = $0 { return true }
            return false
        }.count
    }
}

extension GameSession: Equatable {
    static func == (lhs: GameSession, rhs: GameSession) -> Bool {
        lhs.events.elementsEqual(rhs.events, by: sessionEventsAreEqual)
    }
}

private func sessionEventsAreEqual(_ lhs: SessionEvent, _ rhs: SessionEvent) -> Bool {
    switch (lhs, rhs) {
    case let (.gameStarted(leftTimestamp), .gameStarted(rightTimestamp)):
        return leftTimestamp == rightTimestamp
    case let (.roundStarted(leftName, leftEmoji, leftTimestamp), .roundStarted(rightName, rightEmoji, rightTimestamp)):
        return leftName == rightName && leftEmoji == rightEmoji && leftTimestamp == rightTimestamp
    case let (.roundFinished(leftName, leftTimestamp), .roundFinished(rightName, rightTimestamp)):
        return leftName == rightName && leftTimestamp == rightTimestamp
    case let (.skipped(leftName, leftTimestamp), .skipped(rightName, rightTimestamp)):
        return leftName == rightName && leftTimestamp == rightTimestamp
    case let (.doOver(leftPlayer, leftTimestamp), .doOver(rightPlayer, rightTimestamp)):
        return leftPlayer == rightPlayer && leftTimestamp == rightTimestamp
    case let (.restartTimer(leftName, leftTimestamp), .restartTimer(rightName, rightTimestamp)):
        return leftName == rightName && leftTimestamp == rightTimestamp
    case let (.paused(leftTimestamp), .paused(rightTimestamp)):
        return leftTimestamp == rightTimestamp
    case let (.resumed(leftTimestamp), .resumed(rightTimestamp)):
        return leftTimestamp == rightTimestamp
    case let (.gameEnded(leftTimestamp), .gameEnded(rightTimestamp)):
        return leftTimestamp == rightTimestamp
    default:
        return false
    }
}

// MARK: - Game Record

struct GameRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var gameTitle: String
    var session: GameSession
    /// Snapshot of active player names at game start (ordered).
    var playerNames: [String]
    var playedAt: Date
}

// MARK: - History Store

struct HistoryStore {
    private let documentsDirectory: URL
    private let fileManager: FileManager

    private var historyURL: URL {
        documentsDirectory.appendingPathComponent("History", isDirectory: true)
    }

    init(documentsDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.documentsDirectory = documentsDirectory
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? fileManager.createDirectory(at: historyURL, withIntermediateDirectories: true)
    }

    func save(_ record: GameRecord) {
        let url = historyFileURL(for: record.id)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(record) else {
            print("HistoryStore: failed to encode record \(record.id)")
            return
        }
        do {
            try data.write(to: url)
        } catch {
            print("HistoryStore: failed to write record: \(error)")
        }
    }

    func save(document: HistoryDocument) {
        save(document.record)
        try? fileManager.setAttributes(
            [.modificationDate: document.modifiedAt],
            ofItemAtPath: historyFileURL(for: document.record.id).path
        )
    }

    func load(id: UUID) -> GameRecord? {
        let url = historyFileURL(for: id)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(GameRecord.self, from: data)
    }

    func loadDocument(id: UUID) -> HistoryDocument? {
        guard let record = load(id: id) else { return nil }
        let modifiedAt = modificationDate(for: historyFileURL(for: id)) ?? record.playedAt
        return HistoryDocument(record: record, modifiedAt: modifiedAt)
    }

    func loadAll() -> [GameRecord] {
        let decoder = JSONDecoder()
        guard let files = try? fileManager.contentsOfDirectory(
            at: historyURL, includingPropertiesForKeys: nil
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "vtlog" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let record = try? decoder.decode(GameRecord.self, from: data)
                else {
                    print("HistoryStore: skipping corrupt file \(url.lastPathComponent)")
                    return nil
                }
                return record
            }
            .sorted { $0.playedAt > $1.playedAt }
    }

    func delete(id: UUID) {
        let url = historyFileURL(for: id)
        try? fileManager.removeItem(at: url)
    }

    func exportURL(for record: GameRecord) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(record) else {
            print("HistoryStore: failed to encode record for export \(record.id)")
            return nil
        }
        let tempURL = fileManager.temporaryDirectory
            .appendingPathComponent(TemplateImportExport.safeFileName(for: record.gameTitle))
            .appendingPathExtension("vtlog")
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("HistoryStore: failed to write export file: \(error)")
            return nil
        }
    }

    private func historyFileURL(for id: UUID) -> URL {
        historyURL.appendingPathComponent("\(id.uuidString).vtlog")
    }

    private func modificationDate(for url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }
}

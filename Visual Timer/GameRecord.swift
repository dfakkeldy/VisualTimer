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

// MARK: - Game Record

struct GameRecord: Identifiable, Codable {
    var id: UUID
    var gameTitle: String
    var session: GameSession
    /// Snapshot of active player names at game start (ordered).
    var playerNames: [String]
    var playedAt: Date
}

// MARK: - History Store

struct HistoryStore {
    private var historyURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("History", isDirectory: true)
    }

    init() {
        try? FileManager.default.createDirectory(at: historyURL, withIntermediateDirectories: true)
    }

    func save(_ record: GameRecord) {
        let url = historyURL.appendingPathComponent("\(record.id.uuidString).vtlog")
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

    func loadAll() -> [GameRecord] {
        let decoder = JSONDecoder()
        guard let files = try? FileManager.default.contentsOfDirectory(
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
        let url = historyURL.appendingPathComponent("\(id.uuidString).vtlog")
        try? FileManager.default.removeItem(at: url)
    }

    func exportURL(for record: GameRecord) -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(record.gameTitle).vtlog")
        if let data = try? encoder.encode(record) {
            try? data.write(to: tempURL)
        }
        return tempURL
    }
}

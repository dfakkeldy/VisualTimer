import SwiftUI
import Combine

final class HistoryViewModel: ObservableObject {

    @Published var records: [GameRecord] = []

    var onRecordDeleted: ((UUID) -> Void)?

    private let store: HistoryStore

    init(store: HistoryStore = HistoryStore()) {
        self.store = store
        loadRecords()
    }

    func loadRecords() {
        records = store.loadAll()
    }

    func deleteRecord(id: UUID) {
        store.delete(id: id)
        records.removeAll { $0.id == id }
        onRecordDeleted?(id)
    }

    func recordSaved(_ record: GameRecord) {
        records.removeAll { $0.id == record.id }
        records.append(record)
        records.sort { $0.playedAt > $1.playedAt }
    }

    func exportURL(for record: GameRecord) -> URL? {
        store.exportURL(for: record)
    }

    func populateSampleRecords() {
        let now = Date()
        let calendar = Calendar.current
        let sampleSessions: [(String, [(String, String)], Int, Int, TimeInterval, Int)] = [
            ("Game Night", [("Alice", "🎮"), ("Bob", "🎯"), ("Charlie", "🎲"), ("Diana", "♟️")], 1, 0, 540, -1),
            ("Quick Match", [("Alice", "🎮"), ("Bob", "🎯")], 2, 1, 720, -3),
            ("Solo Practice", [("Alice", "🎮")], 0, 0, 180, -7),
        ]
        for (title, players, skips, doOvers, elapsed, daysAgo) in sampleSessions {
            let pastDate = calendar.date(byAdding: .day, value: daysAgo, to: now) ?? now
            var events: [SessionEvent] = [.gameStarted(timestamp: pastDate)]
            var t = pastDate.addingTimeInterval(1)
            for (_, player) in players.enumerated() {
                events.append(.roundStarted(playerName: player.0, emoji: player.1, timestamp: t))
                t = t.addingTimeInterval(elapsed / Double(players.count))
                events.append(.roundFinished(playerName: player.0, timestamp: t))
            }
            for _ in 0..<skips {
                events.append(.skipped(playerName: players[0].0, timestamp: t))
            }
            for _ in 0..<doOvers {
                events.append(.doOver(previousPlayer: players[0].0, timestamp: t))
            }
            events.append(.gameEnded(timestamp: t))
            let session = GameSession(events: events)
            let record = GameRecord(id: UUID(), gameTitle: title, session: session, playerNames: players.map(\.0), playedAt: pastDate)
            store.save(record)
        }
        loadRecords()
    }
}

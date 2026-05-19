import SwiftUI
import Combine

final class HistoryViewModel: ObservableObject {

    @Published var records: [GameRecord] = []

    private let store = HistoryStore()

    init() {
        loadRecords()
    }

    func loadRecords() {
        records = store.loadAll()
    }

    func deleteRecord(id: UUID) {
        store.delete(id: id)
        records.removeAll { $0.id == id }
    }

    func exportURL(for record: GameRecord) -> URL? {
        store.exportURL(for: record)
    }
}

import Foundation

struct HistoryDocument: Codable, Equatable {
    static let schemaVersion = 1

    var schemaVersion: Int
    var record: GameRecord
    var modifiedAt: Date

    init(schemaVersion: Int = Self.schemaVersion, record: GameRecord, modifiedAt: Date = Date()) {
        self.schemaVersion = schemaVersion
        self.record = record
        self.modifiedAt = modifiedAt
    }
}

import CloudKit
import Foundation

struct HistoryCloudRecordMapper {
    private enum Field {
        static let payload = "payload"
        static let gameTitle = "gameTitle"
        static let playedAt = "playedAt"
        static let modifiedAt = "modifiedAt"
    }

    private let configuration: HistorySyncConfiguration
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(configuration: HistorySyncConfiguration = HistorySyncConfiguration()) {
        self.configuration = configuration
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func recordID(for historyID: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: historyID.uuidString, zoneID: configuration.zoneID)
    }

    func record(from document: HistoryDocument) throws -> CKRecord {
        let record = CKRecord(
            recordType: HistorySyncConfiguration.recordType,
            recordID: recordID(for: document.record.id)
        )
        record[Field.payload] = try encoder.encode(document) as NSData
        record[Field.gameTitle] = document.record.gameTitle as CKRecordValue
        record[Field.playedAt] = document.record.playedAt as CKRecordValue
        record[Field.modifiedAt] = document.modifiedAt as CKRecordValue
        return record
    }

    func document(from record: CKRecord) throws -> HistoryDocument {
        guard record.recordType == HistorySyncConfiguration.recordType,
              let payload = record[Field.payload] as? NSData else {
            throw CloudSyncError.unknownRecordType(record.recordType)
        }
        return try decoder.decode(HistoryDocument.self, from: payload as Data)
    }
}

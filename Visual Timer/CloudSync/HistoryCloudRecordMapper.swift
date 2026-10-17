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
    private let codec: HistoryDocumentCodec

    init(
        configuration: HistorySyncConfiguration = HistorySyncConfiguration(),
        codec: HistoryDocumentCodec = HistoryDocumentCodec()
    ) {
        self.configuration = configuration
        self.codec = codec
    }

    func recordID(for historyID: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: historyID.uuidString, zoneID: configuration.zoneID)
    }

    func record(from document: HistoryDocument) throws -> CKRecord {
        let record = CKRecord(
            recordType: HistorySyncConfiguration.recordType,
            recordID: recordID(for: document.record.id)
        )
        record[Field.payload] = try codec.encode(document) as NSData
        record[Field.gameTitle] = document.record.gameTitle as CKRecordValue
        record[Field.playedAt] = document.record.playedAt as CKRecordValue
        record[Field.modifiedAt] = document.modifiedAt as CKRecordValue
        return record
    }

    func document(from record: CKRecord) throws -> HistoryDocument {
        guard record.recordType == HistorySyncConfiguration.recordType else {
            throw CloudSyncError.unknownRecordType(record.recordType)
        }
        guard let payload = record[Field.payload] as? NSData else {
            throw HistoryDocumentError.invalidHistoryFile
        }

        var document = try codec.decode(payload as Data)
        guard document.record.id.uuidString == record.recordID.recordName else {
            throw CloudSyncError.recordIDMismatch(
                recordName: record.recordID.recordName,
                payloadID: document.record.id.uuidString
            )
        }
        if let modifiedAt = record[Field.modifiedAt] as? Date {
            document.modifiedAt = modifiedAt
        }
        return document
    }
}

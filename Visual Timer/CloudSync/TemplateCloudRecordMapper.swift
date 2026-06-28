import CloudKit
import Foundation

struct TemplateCloudRecordMapper {
    private enum Field {
        static let title = "title"
        static let payload = "payload"
        static let createdAt = "createdAt"
        static let modifiedAt = "modifiedAt"
        static let exportedAt = "exportedAt"
    }

    private let configuration: TemplateSyncConfiguration
    private let codec: TemplateDocumentCodec

    init(
        configuration: TemplateSyncConfiguration = TemplateSyncConfiguration(),
        codec: TemplateDocumentCodec = TemplateDocumentCodec()
    ) {
        self.configuration = configuration
        self.codec = codec
    }

    func recordID(for templateID: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: templateID.uuidString, zoneID: configuration.zoneID)
    }

    func record(from document: TurnTimerTemplateDocument) throws -> CKRecord {
        let record = CKRecord(
            recordType: TemplateSyncConfiguration.recordType,
            recordID: recordID(for: document.templateID)
        )
        try apply(document: document, to: record)
        return record
    }

    func apply(document: TurnTimerTemplateDocument, to record: CKRecord) throws {
        record[Field.title] = document.title as CKRecordValue
        record[Field.payload] = try codec.encode(document) as NSData
        record[Field.createdAt] = document.createdAt as CKRecordValue
        record[Field.modifiedAt] = document.modifiedAt as CKRecordValue
        record[Field.exportedAt] = document.exportedAt as CKRecordValue
    }

    func document(from record: CKRecord) throws -> TurnTimerTemplateDocument {
        guard record.recordType == TemplateSyncConfiguration.recordType else {
            throw CloudSyncError.unknownRecordType(record.recordType)
        }
        guard let payload = record[Field.payload] as? NSData else {
            throw TemplateDocumentError.invalidTemplateFile
        }

        var document = try codec.decode(payload as Data)
        if let title = record[Field.title] as? String {
            document.title = title
            document.game.title = title
        }
        if let modifiedAt = record[Field.modifiedAt] as? Date {
            document.modifiedAt = modifiedAt
        }
        return document
    }
}

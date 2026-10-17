import Foundation

struct HistoryDocument: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var record: GameRecord
    var modifiedAt: Date

    init(schemaVersion: Int = Self.currentSchemaVersion, record: GameRecord, modifiedAt: Date = Date()) {
        self.schemaVersion = schemaVersion
        self.record = record
        self.modifiedAt = modifiedAt
    }
}

struct HistoryDocumentCodec {
    func encode(_ document: HistoryDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    func decode(_ data: Data) throws -> HistoryDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(HistoryDocument.self, from: data)
        guard document.schemaVersion <= HistoryDocument.currentSchemaVersion else {
            throw HistoryDocumentError.unsupportedSchemaVersion(document.schemaVersion)
        }
        return document
    }
}

enum HistoryDocumentError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    case invalidHistoryFile

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "This history record uses a newer file format (version \(version))."
        case .invalidHistoryFile:
            return "This file is not a valid Turn Timer history record."
        }
    }
}

import Foundation

struct TurnTimerTemplateDocument: Codable, Equatable, Identifiable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var templateID: UUID
    var title: String
    var game: GameSequence
    var createdAt: Date
    var modifiedAt: Date
    var exportedAt: Date

    var id: UUID { templateID }

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        templateID: UUID = UUID(),
        title: String,
        game: GameSequence,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        exportedAt: Date = Date()
    ) {
        var normalizedGame = game
        normalizedGame.title = title
        normalizedGame.reindexRounds()

        self.schemaVersion = schemaVersion
        self.templateID = templateID
        self.title = title
        self.game = normalizedGame
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.exportedAt = exportedAt
    }
}

struct SavedTemplate: Identifiable, Equatable {
    let id: UUID
    let title: String
    let roundCount: Int
    let repeatCount: Int
    let modifiedAt: Date
    let url: URL

    var subtitle: String {
        let roundWord = roundCount == 1 ? "round" : "rounds"
        let repeatWord = repeatCount == 1 ? "once" : "\(repeatCount)x"
        return "\(roundCount) \(roundWord) • \(repeatWord)"
    }
}

struct TemplateDocumentCodec {
    func encode(_ document: TurnTimerTemplateDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    func decode(_ data: Data) throws -> TurnTimerTemplateDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(TurnTimerTemplateDocument.self, from: data)
        guard document.schemaVersion <= TurnTimerTemplateDocument.currentSchemaVersion else {
            throw TemplateDocumentError.unsupportedSchemaVersion(document.schemaVersion)
        }
        return document
    }

    func decode(from url: URL) throws -> TurnTimerTemplateDocument {
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    func write(_ document: TurnTimerTemplateDocument, to url: URL) throws {
        let data = try encode(document)
        try data.write(to: url, options: [.atomic])
    }
}

enum TemplateDocumentError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    case invalidTemplateFile

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "This template uses a newer file format (version \(version))."
        case .invalidTemplateFile:
            return "This file is not a valid Turn Timer template."
        }
    }
}

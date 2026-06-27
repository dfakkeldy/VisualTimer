import Foundation

final class TemplateLibraryStore {
    private let documentsDirectory: URL
    private let templatesDirectory: URL
    private let fileManager: FileManager
    private let codec: TemplateDocumentCodec
    private let parser: GameFileParser
    private let dateProvider: () -> Date

    init(
        documentsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        codec: TemplateDocumentCodec = TemplateDocumentCodec(),
        parser: GameFileParser = GameFileParser(),
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        let defaultDocumentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let resolvedDocumentsDirectory = documentsDirectory ?? defaultDocumentsDirectory

        self.documentsDirectory = resolvedDocumentsDirectory
        self.templatesDirectory = resolvedDocumentsDirectory.appendingPathComponent("Templates", isDirectory: true)
        self.fileManager = fileManager
        self.codec = codec
        self.parser = parser
        self.dateProvider = dateProvider
    }

    func listTemplates() -> [SavedTemplate] {
        guard fileManager.fileExists(atPath: templatesDirectory.path),
              let urls = try? fileManager.contentsOfDirectory(
                at: templatesDirectory,
                includingPropertiesForKeys: nil
              )
        else {
            return []
        }

        return urls
            .filter { $0.pathExtension.lowercased() == TemplateImportExport.fileExtension }
            .compactMap { try? savedTemplate(at: $0) }
            .sorted { lhs, rhs in
                if lhs.modifiedAt == rhs.modifiedAt {
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
                return lhs.modifiedAt > rhs.modifiedAt
            }
    }

    func loadDocument(id: UUID) throws -> TurnTimerTemplateDocument {
        try codec.decode(from: templateURL(for: id))
    }

    func save(game: GameSequence, templateID: UUID? = nil) throws -> SavedTemplate {
        let now = dateProvider()
        let id = templateID ?? UUID()
        let existingDocument = try? loadDocument(id: id)
        let document = TurnTimerTemplateDocument(
            templateID: id,
            title: normalizedTitle(game.title),
            game: game,
            createdAt: existingDocument?.createdAt ?? now,
            modifiedAt: now,
            exportedAt: now
        )
        return try save(document: document)
    }

    func save(document: TurnTimerTemplateDocument) throws -> SavedTemplate {
        try ensureTemplatesDirectoryExists()

        var normalizedGame = document.game
        normalizedGame.title = normalizedTitle(document.title)
        normalizedGame.reindexRounds()

        let normalizedDocument = TurnTimerTemplateDocument(
            schemaVersion: document.schemaVersion,
            templateID: document.templateID,
            title: normalizedGame.title,
            game: normalizedGame,
            createdAt: document.createdAt,
            modifiedAt: document.modifiedAt,
            exportedAt: document.exportedAt
        )
        let url = templateURL(for: normalizedDocument.templateID)
        try codec.write(normalizedDocument, to: url)
        return metadata(for: normalizedDocument, at: url)
    }

    func importTemplate(from url: URL) throws -> SavedTemplate {
        let document = try codec.decode(from: url)
        return try importTemplate(document)
    }

    func importTemplate(_ document: TurnTimerTemplateDocument) throws -> SavedTemplate {
        let now = dateProvider()
        let title = uniqueImportedTitle(for: document.title)
        var game = document.game
        game.id = UUID()
        game.title = title
        game.createdAt = now
        game.modifiedAt = now
        game.reindexRounds()

        let copy = TurnTimerTemplateDocument(
            templateID: UUID(),
            title: title,
            game: game,
            createdAt: now,
            modifiedAt: now,
            exportedAt: now
        )
        return try save(document: copy)
    }

    func deleteTemplate(id: UUID) throws {
        let url = templateURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func migrateLegacyTemplateIfNeeded(fileName: String) throws -> SavedTemplate? {
        guard !fileName.isEmpty,
              fileName.hasSuffix(".vtgame")
        else {
            return nil
        }

        let url = documentsDirectory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        let content = try String(contentsOf: url, encoding: .utf8)
        let (game, errors) = parser.parse(content)
        guard errors.isEmpty else {
            throw TemplateLibraryError.legacyTemplateParseFailed(errors)
        }

        if let existing = listTemplates().first(where: { $0.title == game.title }) {
            return existing
        }

        return try save(game: game)
    }

    func exportDocument(for game: GameSequence, templateID: UUID? = nil) -> TurnTimerTemplateDocument {
        let now = dateProvider()
        return TurnTimerTemplateDocument(
            templateID: templateID ?? UUID(),
            title: normalizedTitle(game.title),
            game: game,
            createdAt: game.createdAt,
            modifiedAt: now,
            exportedAt: now
        )
    }

    private func templateURL(for id: UUID) -> URL {
        templatesDirectory
            .appendingPathComponent(id.uuidString)
            .appendingPathExtension(TemplateImportExport.fileExtension)
    }

    private func savedTemplate(at url: URL) throws -> SavedTemplate {
        let document = try codec.decode(from: url)
        return metadata(for: document, at: url)
    }

    private func metadata(for document: TurnTimerTemplateDocument, at url: URL) -> SavedTemplate {
        SavedTemplate(
            id: document.templateID,
            title: document.title,
            roundCount: document.game.rounds.count,
            repeatCount: document.game.roundCount,
            modifiedAt: document.modifiedAt,
            url: url
        )
    }

    private func ensureTemplatesDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: templatesDirectory.path) else { return }
        try fileManager.createDirectory(at: templatesDirectory, withIntermediateDirectories: true)
    }

    private func uniqueImportedTitle(for title: String) -> String {
        let baseTitle = normalizedTitle(title)
        let existingTitles = Set(listTemplates().map(\.title))
        guard existingTitles.contains(baseTitle) else { return baseTitle }

        let copyTitle = "\(baseTitle) Copy"
        guard existingTitles.contains(copyTitle) else { return copyTitle }

        var suffix = 2
        while existingTitles.contains("\(copyTitle) \(suffix)") {
            suffix += 1
        }
        return "\(copyTitle) \(suffix)"
    }

    private func normalizedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Template" : trimmed
    }
}

enum TemplateLibraryError: LocalizedError {
    case legacyTemplateParseFailed([ParseError])

    var errorDescription: String? {
        switch self {
        case .legacyTemplateParseFailed(let errors):
            return errors.map(\.message).joined(separator: "\n")
        }
    }
}

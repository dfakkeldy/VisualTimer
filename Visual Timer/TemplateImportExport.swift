import Foundation
import UniformTypeIdentifiers

extension UTType {
    static var turnTimerTemplate: UTType {
        UTType(exportedAs: "com.fakkeldy.turntimer.template", conformingTo: .json)
    }
}

enum TemplateImportExport {
    static let fileExtension = "turntimer"

    static func exportURL(
        for document: TurnTimerTemplateDocument,
        codec: TemplateDocumentCodec = TemplateDocumentCodec()
    ) throws -> URL {
        let fileName = safeFileName(for: document.title)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension(fileExtension)
        try codec.write(document, to: url)
        return url
    }

    static func safeFileName(for title: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = title
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Turn Timer Template" : cleaned
    }
}

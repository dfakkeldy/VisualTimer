import Foundation

enum TemplateSavePolicy {
    static func canSaveTemplate(
        isProUnlocked: Bool,
        lastSavedFileName: String,
        proposedFileName: String
    ) -> Bool {
        guard !isProUnlocked else { return true }
        guard !lastSavedFileName.isEmpty else { return true }
        return lastSavedFileName == proposedFileName
    }
}

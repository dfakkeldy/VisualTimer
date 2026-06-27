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

    static func canSaveTemplate(
        isProUnlocked: Bool,
        existingTemplateCount: Int,
        isUpdatingExistingTemplate: Bool
    ) -> Bool {
        guard !isProUnlocked else { return true }
        guard !isUpdatingExistingTemplate else { return true }
        return existingTemplateCount == 0
    }
}

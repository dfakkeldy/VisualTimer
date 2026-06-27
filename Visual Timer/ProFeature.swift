import Foundation

enum ProFeature: Identifiable, Equatable {
    case unlimitedTemplates
    case historyExport
    case fullHistory

    var id: String {
        switch self {
        case .unlimitedTemplates:
            return "unlimited-templates"
        case .historyExport:
            return "history-export"
        case .fullHistory:
            return "full-history"
        }
    }

    var title: String {
        switch self {
        case .unlimitedTemplates:
            return "Save unlimited templates"
        case .historyExport:
            return "Export session history"
        case .fullHistory:
            return "View full history"
        }
    }

    var message: String {
        switch self {
        case .unlimitedTemplates:
            return "Free includes starter templates and one custom saved template. Pro unlocks unlimited saved templates."
        case .historyExport:
            return "Pro unlocks exporting completed sessions for sharing or archiving."
        case .fullHistory:
            return "Free keeps recent sessions. Pro unlocks your full local history."
        }
    }
}

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

    /// Why the sheet opened, in the words of what the person tapped.
    var title: String {
        switch self {
        case .unlimitedTemplates:
            return "Save more templates"
        case .historyExport:
            return "Export a session"
        case .fullHistory:
            return "See your full history"
        }
    }

    var message: String {
        switch self {
        case .unlimitedTemplates:
            return "Free includes every starter template and one saved template of your own. Pro saves as many as you like."
        case .historyExport:
            return "Pro exports any finished session as a file you can share or keep."
        case .fullHistory:
            return "Free shows your \(HistoryAccessPolicy.freeRecordLimit) most recent sessions; older ones are kept and appear when you unlock."
        }
    }

    /// Everything Pro adds, in one order everywhere it's listed.
    static let benefits: [(symbol: String, text: String)] = [
        ("rectangle.stack.badge.plus", "Unlimited saved templates"),
        ("clock.arrow.circlepath", "Full history and export"),
        ("icloud", "iCloud sync of templates and history"),
        ("square.and.arrow.up", "Template sharing"),
        ("square.grid.2x2", "Home Screen and Lock Screen widgets"),
    ]

    /// The benefit that opened the sheet comes first.
    var orderedBenefits: [(symbol: String, text: String)] {
        let leadIndex: Int
        switch self {
        case .unlimitedTemplates: leadIndex = 0
        case .historyExport, .fullHistory: leadIndex = 1
        }
        var list = Self.benefits
        let lead = list.remove(at: leadIndex)
        return [lead] + list
    }

    static var benefitsSentence: String {
        "Pro adds unlimited saved templates, full history and export, iCloud sync, template sharing, and Home Screen and Lock Screen widgets. One-time purchase."
    }
}

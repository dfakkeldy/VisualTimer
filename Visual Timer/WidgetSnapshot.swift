import Foundation

struct WidgetTemplateSnapshot: Identifiable, Codable, Equatable {
    enum Source: String, Codable {
        case starter
        case saved
    }

    var id: String
    var title: String
    var subtitle: String
    var source: Source
    var templateID: UUID?
    var starterID: String?
    var totalSeconds: Int
    var roundCount: Int
    var modifiedAt: Date

    var launchURL: URL {
        switch source {
        case .starter:
            return URL(string: "turntimer://starter/\(starterID ?? id)")!
        case .saved:
            return URL(string: "turntimer://template/\(templateID?.uuidString ?? id)")!
        }
    }
}

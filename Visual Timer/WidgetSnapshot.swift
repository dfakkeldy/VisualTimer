import Foundation

struct WidgetTemplateSnapshot: Identifiable, Codable, Equatable {
    enum Source: String, Codable {
        case starter
        case saved
        case locked
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

    var launchURL: URL? {
        switch source {
        case .starter:
            return URL(string: "turntimer://starter/\(starterID ?? id)")!
        case .saved:
            return URL(string: "turntimer://template/\(templateID?.uuidString ?? id)")!
        case .locked:
            return nil
        }
    }

    var durationText: String {
        let clampedSeconds = max(0, totalSeconds)
        let hours = clampedSeconds / 3_600
        let minutes = (clampedSeconds % 3_600) / 60
        let seconds = clampedSeconds % 60

        if hours > 0 {
            return "\(hours):" + String(format: "%02d:%02d", minutes, seconds)
        }

        return "\(minutes):" + String(format: "%02d", seconds)
    }
}

extension WidgetTemplateSnapshot {
    nonisolated static var proLocked: WidgetTemplateSnapshot {
        WidgetTemplateSnapshot(
            id: "turn-timer-pro",
            title: "Turn Timer Pro",
            subtitle: "Unlock widgets in the app.",
            source: .locked,
            templateID: nil,
            starterID: nil,
            totalSeconds: 0,
            roundCount: 0,
            modifiedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

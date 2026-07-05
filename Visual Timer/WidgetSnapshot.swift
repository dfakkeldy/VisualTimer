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
            return URL(string: "turntimer://pro")!
        }
    }

    var roundCountText: String {
        TurnTimerCountText.label(for: roundCount, singular: "round")
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

    static func selectableSnapshots(from snapshots: [WidgetTemplateSnapshot]) -> [WidgetTemplateSnapshot] {
        snapshots.filter { $0.source != .locked }
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

enum TurnTimerCountText {
    static func label(for count: Int, singular: String, plural: String? = nil) -> String {
        let noun = count == 1 ? singular : (plural ?? "\(singular)s")
        return "\(count) \(noun)"
    }
}

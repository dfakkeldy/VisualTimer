import Foundation

enum SessionEvent {
    case gameStarted(timestamp: Date)
    case roundStarted(playerName: String, emoji: String, timestamp: Date)
    case roundFinished(playerName: String, timestamp: Date)
    case skipped(playerName: String, timestamp: Date)
    case doOver(previousPlayer: String, timestamp: Date)
    case restartTimer(playerName: String, timestamp: Date)
    case paused(timestamp: Date)
    case resumed(timestamp: Date)
    case gameEnded(timestamp: Date)
}

// MARK: - Codable

extension SessionEvent: Codable {

    private enum CodingKeys: String, CodingKey {
        case type
        case timestamp
        case playerName
        case emoji
        case previousPlayer
    }

    private enum EventType: String, Codable {
        case gameStarted
        case roundStarted
        case roundFinished
        case skipped
        case doOver
        case restartTimer
        case paused
        case resumed
        case gameEnded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EventType.self, forKey: .type)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)

        switch type {
        case .gameStarted:
            self = .gameStarted(timestamp: timestamp)
        case .roundStarted:
            let name = try container.decode(String.self, forKey: .playerName)
            let emoji = try container.decode(String.self, forKey: .emoji)
            self = .roundStarted(playerName: name, emoji: emoji, timestamp: timestamp)
        case .roundFinished:
            let name = try container.decode(String.self, forKey: .playerName)
            self = .roundFinished(playerName: name, timestamp: timestamp)
        case .skipped:
            let name = try container.decode(String.self, forKey: .playerName)
            self = .skipped(playerName: name, timestamp: timestamp)
        case .doOver:
            let prev = try container.decode(String.self, forKey: .previousPlayer)
            self = .doOver(previousPlayer: prev, timestamp: timestamp)
        case .restartTimer:
            let name = try container.decode(String.self, forKey: .playerName)
            self = .restartTimer(playerName: name, timestamp: timestamp)
        case .paused:
            self = .paused(timestamp: timestamp)
        case .resumed:
            self = .resumed(timestamp: timestamp)
        case .gameEnded:
            self = .gameEnded(timestamp: timestamp)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .gameStarted(let ts):
            try container.encode(EventType.gameStarted, forKey: .type)
            try container.encode(ts, forKey: .timestamp)
        case .roundStarted(let name, let emoji, let ts):
            try container.encode(EventType.roundStarted, forKey: .type)
            try container.encode(name, forKey: .playerName)
            try container.encode(emoji, forKey: .emoji)
            try container.encode(ts, forKey: .timestamp)
        case .roundFinished(let name, let ts):
            try container.encode(EventType.roundFinished, forKey: .type)
            try container.encode(name, forKey: .playerName)
            try container.encode(ts, forKey: .timestamp)
        case .skipped(let name, let ts):
            try container.encode(EventType.skipped, forKey: .type)
            try container.encode(name, forKey: .playerName)
            try container.encode(ts, forKey: .timestamp)
        case .doOver(let prev, let ts):
            try container.encode(EventType.doOver, forKey: .type)
            try container.encode(prev, forKey: .previousPlayer)
            try container.encode(ts, forKey: .timestamp)
        case .restartTimer(let name, let ts):
            try container.encode(EventType.restartTimer, forKey: .type)
            try container.encode(name, forKey: .playerName)
            try container.encode(ts, forKey: .timestamp)
        case .paused(let ts):
            try container.encode(EventType.paused, forKey: .type)
            try container.encode(ts, forKey: .timestamp)
        case .resumed(let ts):
            try container.encode(EventType.resumed, forKey: .type)
            try container.encode(ts, forKey: .timestamp)
        case .gameEnded(let ts):
            try container.encode(EventType.gameEnded, forKey: .type)
            try container.encode(ts, forKey: .timestamp)
        }
    }
}

// MARK: - Display Helpers

extension SessionEvent {
    /// SF Symbol name for the event icon in the timeline.
    var iconName: String {
        switch self {
        case .gameStarted: return "flag.fill"
        case .roundStarted: return "play.circle.fill"
        case .roundFinished: return "checkmark.circle.fill"
        case .skipped: return "forward.end.fill"
        case .doOver: return "arrow.uturn.backward"
        case .restartTimer: return "arrow.counterclockwise.circle"
        case .paused: return "pause.circle.fill"
        case .resumed: return "play.circle"
        case .gameEnded: return "flag.checkered"
        }
    }

    /// Human-readable label for the event in the timeline.
    var label: String {
        switch self {
        case .gameStarted: return "Session started"
        case .roundStarted(let name, _, _): return "\(name) — round started"
        case .roundFinished(let name, _): return "\(name) — round finished"
        case .skipped(let name, _): return "\(name) — skipped"
        case .doOver(let prev, _): return "Do-over to \(prev)"
        case .restartTimer(let name, _): return "\(name) — timer restarted"
        case .paused: return "Paused"
        case .resumed: return "Resumed"
        case .gameEnded: return "Session complete"
        }
    }

    /// The timestamp for this event.
    var timestamp: Date {
        switch self {
        case .gameStarted(let ts),
             .roundStarted(_, _, let ts),
             .roundFinished(_, let ts),
             .skipped(_, let ts),
             .doOver(_, let ts),
             .restartTimer(_, let ts),
             .paused(let ts),
             .resumed(let ts),
             .gameEnded(let ts):
            return ts
        }
    }
}

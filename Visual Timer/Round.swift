import SwiftUI

// MARK: - Round Color

enum RoundColor: Equatable, Codable {
    case palette(index: Int)
    case custom(hex: String)

    var swiftUIColor: Color {
        switch self {
        case .palette(let index):
            let palette = Theme.ColorValue.timerPalette
            guard !palette.isEmpty else { return .red }
            return palette[index % palette.count]
        case .custom(let hex):
            return Color(hex: hex) ?? .red
        }
    }

    var displayName: String {
        switch self {
        case .palette(let index):
            let names = ["Red", "Orange", "Yellow", "Green", "Mint", "Teal",
                         "Cyan", "Blue", "Indigo", "Purple", "Pink", "Brown",
                         "Deep Orange", "Lime Green", "Hot Pink", "Royal Blue"]
            guard index >= 0, index < names.count else { return "Unknown" }
            return names[index]
        case .custom(let hex):
            return hex
        }
    }

    static let `default`: RoundColor = .palette(index: 0)
}

// MARK: - Round

struct Round: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var color: RoundColor = .default
    var sound: TimerSound = .chime
    var emoji: String = ""
    var durationSeconds: Int
    var startPaused: Bool = false
    var isActive: Bool = true
    var orderIndex: Int = 0

    /// Display string for duration (e.g., "30s" or "1m 30s").
    var durationDisplay: String {
        if durationSeconds >= 60 {
            let m = durationSeconds / 60
            let s = durationSeconds % 60
            return s > 0 ? "\(m)m \(s)s" : "\(m)m"
        }
        return "\(durationSeconds)s"
    }
}

// MARK: - Game Sequence

struct GameSequence: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var title: String
    var rounds: [Round] = []
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    var activeRounds: [Round] {
        rounds.filter(\.isActive).sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    mutating func reindexRounds() {
        for i in rounds.indices {
            rounds[i].orderIndex = i
        }
        modifiedAt = Date()
    }
}

// MARK: - Hex Color Helper

private extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        guard hex.count == 6,
              let int = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255
        )
    }
}

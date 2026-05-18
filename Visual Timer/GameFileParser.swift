import Foundation

// MARK: - Parse Error

struct ParseError: Error, LocalizedError {
    let message: String
    let roundId: UUID?

    init(_ message: String, roundId: UUID? = nil) {
        self.message = message
        self.roundId = roundId
    }

    var errorDescription: String? { message }
}

// MARK: - Game File Parser

struct GameFileParser {

    // MARK: - Parse

    func parse(_ input: String) -> (GameSequence, [ParseError]) {
        var errors: [ParseError] = []
        var title = "Untitled Game"
        var rounds: [Round] = []
        var currentRound: RoundBuilder?
        var metadataDone = false

        let lines = input.components(separatedBy: .newlines)

        func finalizeCurrentRound(lineNumber: Int) {
            guard let builder = currentRound else { return }
            if let round = builder.build(errors: &errors) {
                rounds.append(round)
            }
            currentRound = nil
        }

        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // Skip blank lines and comments
            if line.isEmpty || line.hasPrefix("#") { continue }

            if line.hasPrefix("[round]") {
                finalizeCurrentRound(lineNumber: index)
                metadataDone = true
                currentRound = RoundBuilder()
                continue
            }

            if !metadataDone {
                // Parse metadata line
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    if key == "title" { title = value }
                }
            } else if let builder = currentRound {
                currentRound = parseRoundField(line: line, builder: builder, lineNumber: index, errors: &errors)
            }
        }

        finalizeCurrentRound(lineNumber: lines.count)

        var game = GameSequence(title: title, rounds: rounds)
        game.reindexRounds()
        return (game, errors)
    }

    // MARK: - Serialize

    func serialize(_ game: GameSequence) -> String {
        var output = ""
        output += "title: \(game.title)\n"
        output += "\n"

        for round in game.rounds.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            output += "[round]\n"
            output += "name: \(round.name)\n"
            output += "color: \(serializeColor(round.color))\n"
            output += "sound: \(round.sound.rawValue)\n"
            if !round.emoji.isEmpty {
                output += "emoji: \(round.emoji)\n"
            }
            output += "time: \(round.durationSeconds)\n"
            output += "paused: \(round.startPaused)\n"
            output += "active: \(round.isActive)\n"
            output += "\n"
        }

        return output
    }

    // MARK: - Private Helpers

    private struct RoundBuilder {
        var name: String?
        var color: RoundColor = .default
        var sound: TimerSound = .chime
        var emoji: String = ""
        var durationSeconds: Int?
        var startPaused = false
        var isActive = true

        func build(errors: inout [ParseError]) -> Round? {
            guard let name else {
                errors.append(ParseError("Round skipped: missing name"))
                return nil
            }
            guard let durationSeconds else {
                errors.append(ParseError("Round '\(name)' skipped: missing time"))
                return nil
            }
            return Round(
                name: name,
                color: color,
                sound: sound,
                emoji: emoji,
                durationSeconds: durationSeconds,
                startPaused: startPaused,
                isActive: isActive
            )
        }
    }

    private func parseRoundField(line: String, builder: RoundBuilder, lineNumber: Int, errors: inout [ParseError]) -> RoundBuilder {
        var builder = builder
        let parts = line.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return builder }

        let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
        let value = parts[1].trimmingCharacters(in: .whitespaces)

        switch key {
        case "name":
            builder.name = value
        case "color":
            builder.color = parseColor(value)
        case "sound":
            builder.sound = TimerSound(rawValue: value) ?? .chime
        case "emoji":
            builder.emoji = value
        case "time":
            if let seconds = Int(value) {
                builder.durationSeconds = max(Theme.TimerMechanic.minimumDuration, seconds)
            } else {
                errors.append(ParseError("Invalid time value '\(value)'"))
            }
        case "paused":
            builder.startPaused = value.lowercased() == "true"
        case "active":
            builder.isActive = value.lowercased() != "false"
        default:
            break
        }

        return builder
    }

    private func parseColor(_ value: String) -> RoundColor {
        // Hex color
        if value.hasPrefix("#") {
            return .custom(hex: value)
        }
        // Named palette colors
        let lower = value.lowercased()
        let names = ["red", "orange", "yellow", "green", "mint", "teal",
                     "cyan", "blue", "indigo", "purple", "pink", "brown",
                     "deep orange", "lime green", "hot pink", "royal blue"]
        if let index = names.firstIndex(of: lower) {
            return .palette(index: index)
        }
        return .default
    }

    private func serializeColor(_ color: RoundColor) -> String {
        switch color {
        case .palette(let index):
            let names = ["red", "orange", "yellow", "green", "mint", "teal",
                         "cyan", "blue", "indigo", "purple", "pink", "brown",
                         "deep orange", "lime green", "hot pink", "royal blue"]
            guard index >= 0, index < names.count else { return "red" }
            return names[index]
        case .custom(let hex):
            return hex
        }
    }
}

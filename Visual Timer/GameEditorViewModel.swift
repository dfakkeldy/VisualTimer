import SwiftUI
import Combine

final class GameEditorViewModel: ObservableObject {

    @Published var gameTitle: String = "New Game"
    @Published var rounds: [Round] = []
    @Published var expandedRoundId: UUID?

    private let parser = GameFileParser()

    var isExpanded: Bool { expandedRoundId != nil }

    // MARK: - Round CRUD

    func addRound() {
        let nextNumber = rounds.count + 1
        let round = Round(
            name: "Player \(nextNumber)",
            durationSeconds: Theme.TimerMechanic.defaultDuration,
            orderIndex: rounds.count
        )
        rounds.append(round)
    }

    func deleteRound(id: UUID) {
        rounds.removeAll { $0.id == id }
        if expandedRoundId == id { expandedRoundId = nil }
        reindex()
    }

    func toggleActive(id: UUID) {
        guard let index = rounds.firstIndex(where: { $0.id == id }) else { return }
        rounds[index].isActive.toggle()
    }

    func toggleExpanded(id: UUID) {
        expandedRoundId = (expandedRoundId == id) ? nil : id
    }

    func moveRounds(from source: IndexSet, to destination: Int) {
        rounds.move(fromOffsets: source, toOffset: destination)
        reindex()
    }

    // MARK: - Round Property Updates

    func updateName(id: UUID, name: String) {
        guard let index = rounds.firstIndex(where: { $0.id == id }) else { return }
        rounds[index].name = name
    }

    func updateColor(id: UUID, color: RoundColor) {
        guard let index = rounds.firstIndex(where: { $0.id == id }) else { return }
        rounds[index].color = color
    }

    func updateSound(id: UUID, sound: TimerSound) {
        guard let index = rounds.firstIndex(where: { $0.id == id }) else { return }
        rounds[index].sound = sound
    }

    func updateEmoji(id: UUID, emoji: String) {
        guard let index = rounds.firstIndex(where: { $0.id == id }) else { return }
        rounds[index].emoji = emoji
    }

    func updateDuration(id: UUID, duration: Int) {
        guard let index = rounds.firstIndex(where: { $0.id == id }) else { return }
        rounds[index].durationSeconds = max(Theme.TimerMechanic.minimumDuration, duration)
    }

    func toggleStartPaused(id: UUID) {
        guard let index = rounds.firstIndex(where: { $0.id == id }) else { return }
        rounds[index].startPaused.toggle()
    }

    // MARK: - Build Sequence

    func buildGameSequence() -> GameSequence {
        var game = GameSequence(title: gameTitle, rounds: rounds)
        game.reindexRounds()
        return game
    }

    // MARK: - File I/O

    func save(to url: URL) -> (Bool, [ParseError]) {
        let game = buildGameSequence()
        let content = parser.serialize(game)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return (true, [])
        } catch {
            return (false, [ParseError("Failed to save: \(error.localizedDescription)")])
        }
    }

    func load(from url: URL) -> (Bool, [ParseError]) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let (game, errors) = parser.parse(content)
            self.gameTitle = game.title
            self.rounds = game.rounds
            return (errors.isEmpty, errors)
        } catch {
            return (false, [ParseError("Failed to load: \(error.localizedDescription)")])
        }
    }

    // MARK: - Private

    private func reindex() {
        for i in rounds.indices {
            rounds[i].orderIndex = i
        }
    }
}

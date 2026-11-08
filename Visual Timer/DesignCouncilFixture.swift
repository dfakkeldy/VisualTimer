#if DEBUG
import Foundation

/// DEBUG-only fixed data for design reviews and screenshot captures.
///
/// Launch with `-designCouncilFixture <scene>`. The app then reads and writes a
/// fresh temporary documents folder seeded with sample templates and history,
/// so the app's own Documents folder is never touched. Release builds compile
/// none of this.
struct DesignCouncilFixture {

    enum Scene: String {
        case quickReady
        case quickPaused
        case sessionTurns
        case sessionRoutine
        case sessionComplete
        case templates
        case history
        case historyEmpty
    }

    let scene: Scene
    let documentsDirectory: URL

    /// Read once at launch from the `-designCouncilFixture` argument.
    static let current: DesignCouncilFixture? = {
        guard let raw = UserDefaults.standard.string(forKey: "designCouncilFixture"),
              let scene = Scene(rawValue: raw) else { return nil }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesignCouncilFixture", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fixture = DesignCouncilFixture(scene: scene, documentsDirectory: directory)
        fixture.seed()
        return fixture
    }()

    /// The tab the scene opens on.
    var initialTab: Int {
        switch scene {
        case .templates: return 1
        case .history, .historyEmpty: return 2
        default: return 0
        }
    }

    // MARK: - Seeding

    private func seed() {
        let templates = TemplateLibraryStore(documentsDirectory: documentsDirectory)
        _ = try? templates.save(game: Self.familyGameNight)

        guard scene != .historyEmpty else { return }
        let history = HistoryStore(documentsDirectory: documentsDirectory)
        for record in Self.historyRecords {
            history.save(record)
        }
    }

    /// 7:15 this morning, so "Today" and "Yesterday" read the same on any capture day.
    private static let referenceDate: Date = {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 7, minute: 15, second: 0, of: Date()) ?? Date()
    }()

    private static let familyGameNight: GameSequence = {
        var game = GameSequence(
            title: "Family Game Night",
            rounds: [
                Round(name: "Maya", color: .palette(index: 7), emoji: "🦊", durationSeconds: 90),
                Round(name: "Theo", color: .palette(index: 3), emoji: "🐢", durationSeconds: 90),
                Round(name: "Grandpa", color: .palette(index: 1), emoji: "🦉", durationSeconds: 120),
                Round(name: "Snack Break", color: .palette(index: 5), emoji: "🍿", durationSeconds: 300, countsAsPlayer: false),
            ],
            roundCount: 3
        )
        game.reindexRounds()
        return game
    }()

    private static let historyRecords: [GameRecord] = [
        record("Morning Routine", daysAgo: 0, steps: [("Wake Up", "⏰", 840), ("Wash Up", "🚿", 290), ("Get Dressed", "👕", 150), ("Breakfast", "🥣", 610)], skips: 1, pauses: 1),
        record("Family Game Night", daysAgo: 1, steps: [("Maya", "🦊", 85), ("Theo", "🐢", 90), ("Grandpa", "🦉", 118), ("Maya", "🦊", 70), ("Theo", "🐢", 88)], doOvers: 1, pauses: 2),
        record("Recipe Steps", daysAgo: 2, steps: [("Prep", "🔪", 60), ("Simmer", "🥘", 300), ("Flip or Stir", "🥄", 120), ("Rest", "⏲️", 180)]),
        record("Morning Routine", daysAgo: 3, steps: [("Wake Up", "⏰", 900), ("Wash Up", "🚿", 300), ("Get Dressed", "👕", 120), ("Breakfast", "🥣", 600), ("Brush Teeth", "🪥", 120)]),
        record("Classroom Stations", daysAgo: 5, steps: [("Station 1", "📚", 300), ("Station 2", "✏️", 300), ("Station 3", "🧪", 300), ("Clean Up", "🧹", 120)], skips: 1),
        record("Meeting Agenda", daysAgo: 8, steps: [("Opening", "👋", 120), ("Updates", "📣", 300), ("Discussion", "💬", 600), ("Decisions", "✅", 180)], pauses: 1),
    ]

    private static func record(
        _ title: String,
        daysAgo: Int,
        steps: [(String, String, Int)],
        skips: Int = 0,
        doOvers: Int = 0,
        pauses: Int = 0
    ) -> GameRecord {
        let start = referenceDate.addingTimeInterval(TimeInterval(-daysAgo * 86_400 - daysAgo * 2_700))
        var clock = start
        var events: [SessionEvent] = [.gameStarted(timestamp: clock)]
        for (index, step) in steps.enumerated() {
            events.append(.roundStarted(playerName: step.0, emoji: step.1, timestamp: clock))
            if index < pauses {
                events.append(.paused(timestamp: clock.addingTimeInterval(TimeInterval(step.2 / 2))))
                events.append(.resumed(timestamp: clock.addingTimeInterval(TimeInterval(step.2 / 2 + 45))))
                clock = clock.addingTimeInterval(45)
            }
            clock = clock.addingTimeInterval(TimeInterval(step.2))
            if index < skips {
                events.append(.skipped(playerName: step.0, timestamp: clock))
            } else if index == 1 && doOvers > 0 {
                events.append(.doOver(previousPlayer: steps[0].0, timestamp: clock))
            } else {
                events.append(.roundFinished(playerName: step.0, timestamp: clock))
            }
        }
        events.append(.gameEnded(timestamp: clock))
        return GameRecord(
            id: UUID(),
            gameTitle: title,
            session: GameSession(events: events),
            playerNames: steps.map(\.0),
            playedAt: start,
            roundColors: Dictionary(steps.map { ($0.0, fixtureColor(for: $0.0)) }, uniquingKeysWith: { first, _ in first })
        )
    }

    /// The colour each sample round has in its template, so History matches.
    private static func fixtureColor(for name: String) -> RoundColor {
        if let round = familyGameNight.rounds.first(where: { $0.name == name }) { return round.color }
        for template in StarterTemplateLibrary.templates {
            if let round = template.game.rounds.first(where: { $0.name == name }) { return round.color }
        }
        return .default
    }

    // MARK: - Applying a scene

    /// Puts the timer and session into the scene's state. Timer dates are
    /// offset from now so the dial and digits land on the same values each run.
    @MainActor
    func apply(to game: GameViewModel) {
        let timer = game.timerViewModel
        let now = Date()
        switch scene {
        case .quickReady, .templates, .history, .historyEmpty:
            break
        case .quickPaused:
            timer.play(at: now)
            timer.pause(at: now.addingTimeInterval(108))
        case .sessionTurns:
            start(StarterTemplateLibrary.template(id: "game-night"), in: game, skipping: 1, elapsed: 22, now: now)
        case .sessionRoutine:
            start(StarterTemplateLibrary.template(id: "morning-routine"), in: game, skipping: 3, elapsed: 230, now: now)
        case .sessionComplete:
            guard let template = StarterTemplateLibrary.template(id: "recipe-steps") else { return }
            game.loadGame(template.game)
            game.startGame()
            // Finish each round the normal way, so the finish reads as it
            // does after a real session.
            for _ in template.game.activeRounds {
                game.handleTimerFinished()
            }
            // Date the start as if the rounds ran their full time.
            if !game.sessionEvents.isEmpty {
                game.sessionEvents[0] = .gameStarted(timestamp: now.addingTimeInterval(TimeInterval(-template.game.totalSeconds)))
            }
        }
    }

    @MainActor
    private func start(_ template: StarterTemplate?, in game: GameViewModel, skipping: Int, elapsed: TimeInterval, now: Date) {
        guard let template else { return }
        game.loadGame(template.game)
        game.startGame()
        for _ in 0..<skipping {
            game.skipCurrentRound()
        }
        // Restart the current round as if it began `elapsed` seconds ago, after
        // the earlier rounds ran their full time.
        let timer = game.timerViewModel
        timer.reconfigureForRound(duration: timer.totalDuration, color: timer.timerColorOverride)
        timer.play(at: now.addingTimeInterval(-elapsed))
        let earlierRounds = template.game.activeRounds.prefix(skipping)
        game.gameElapsedTime = elapsed + Double(earlierRounds.reduce(0) { $0 + $1.durationSeconds })
    }
}
#endif

import XCTest
@testable import Visual_Timer

final class Visual_TimerTests: XCTestCase {

    // MARK: - Round Model

    func testRoundDefaultValues() {
        let round = Round(name: "Test", durationSeconds: 30)
        XCTAssertEqual(round.name, "Test")
        XCTAssertEqual(round.durationSeconds, 30)
        XCTAssertEqual(round.startPaused, false)
        XCTAssertEqual(round.isActive, true)
        XCTAssertEqual(round.emoji, "")
    }

    func testRoundDurationDisplay_secondsOnly() {
        let round = Round(name: "X", durationSeconds: 45)
        XCTAssertEqual(round.durationDisplay, "45s")
    }

    func testRoundDurationDisplay_minutesAndSeconds() {
        let round = Round(name: "X", durationSeconds: 90)
        XCTAssertEqual(round.durationDisplay, "1m 30s")
    }

    func testRoundDurationDisplay_exactMinutes() {
        let round = Round(name: "X", durationSeconds: 120)
        XCTAssertEqual(round.durationDisplay, "2m")
    }

    // MARK: - GameFileParser

    func testParser_roundTrip() {
        let parser = GameFileParser()
        var game = GameSequence(title: "Test Game")
        game.rounds = [
            Round(name: "P1", color: .palette(index: 0), sound: .chime,
                  emoji: "🎮", durationSeconds: 30, startPaused: false, isActive: true, orderIndex: 0),
            Round(name: "P2", color: .palette(index: 3), sound: .deep,
                  emoji: "🎯", durationSeconds: 45, startPaused: true, isActive: true, orderIndex: 1),
        ]

        let serialized = parser.serialize(game)
        let (parsed, errors) = parser.parse(serialized)

        XCTAssertTrue(errors.isEmpty, "Unexpected parse errors: \(errors.map(\.message))")
        XCTAssertEqual(parsed.title, "Test Game")
        XCTAssertEqual(parsed.activeRounds.count, 2)
        XCTAssertEqual(parsed.activeRounds[0].name, "P1")
        XCTAssertEqual(parsed.activeRounds[0].durationSeconds, 30)
        XCTAssertEqual(parsed.activeRounds[0].sound, .chime)
        XCTAssertEqual(parsed.activeRounds[0].startPaused, false)
        XCTAssertEqual(parsed.activeRounds[1].name, "P2")
        XCTAssertEqual(parsed.activeRounds[1].durationSeconds, 45)
        XCTAssertEqual(parsed.activeRounds[1].startPaused, true)
    }

    func testParser_missingNameIsSkipped() {
        let input = """
        title: Test

        [round]
        time: 30

        [round]
        name: Valid
        time: 25
        """

        let parser = GameFileParser()
        let (game, errors) = parser.parse(input)

        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].message.contains("missing name"))
        XCTAssertEqual(game.activeRounds.count, 1)
        XCTAssertEqual(game.activeRounds[0].name, "Valid")
    }

    func testParser_invalidDurationProducesError() {
        let input = """
        title: Test

        [round]
        name: Bad
        time: abc
        """

        let parser = GameFileParser()
        let (game, errors) = parser.parse(input)

        XCTAssertFalse(errors.isEmpty)
        XCTAssertEqual(game.activeRounds.count, 0)
    }

    func testParser_inactiveRoundIsFiltered() {
        let input = """
        title: Test

        [round]
        name: Active
        time: 30
        active: true

        [round]
        name: Skipped
        time: 20
        active: false
        """

        let parser = GameFileParser()
        let (game, errors) = parser.parse(input)

        XCTAssertTrue(errors.isEmpty)
        XCTAssertEqual(game.activeRounds.count, 1)
        XCTAssertEqual(game.activeRounds[0].name, "Active")
    }

    func testParser_commentsAreIgnored() {
        let input = """
        # This is a comment
        title: Commented Game

        # Another comment
        [round]
        name: Solo
        # color: blue
        time: 60
        """

        let parser = GameFileParser()
        let (game, errors) = parser.parse(input)

        XCTAssertTrue(errors.isEmpty)
        XCTAssertEqual(game.title, "Commented Game")
        XCTAssertEqual(game.activeRounds.count, 1)
        XCTAssertEqual(game.activeRounds[0].name, "Solo")
    }

    func testParser_defaultValues() {
        let input = """
        [round]
        name: Minimal
        time: 10
        """

        let parser = GameFileParser()
        let (game, errors) = parser.parse(input)

        XCTAssertTrue(errors.isEmpty)
        let round = game.activeRounds[0]
        XCTAssertEqual(round.color, .default)
        XCTAssertEqual(round.sound, .chime)
        XCTAssertEqual(round.startPaused, false)
        XCTAssertEqual(round.isActive, true)
    }

    // MARK: - GameSequence

    func testGameSequence_reindexRounds() {
        var game = GameSequence(title: "Reorder")
        game.rounds = [
            Round(name: "C", durationSeconds: 10, orderIndex: 2),
            Round(name: "A", durationSeconds: 10, orderIndex: 0),
            Round(name: "B", durationSeconds: 10, orderIndex: 1),
        ]
        game.reindexRounds()

        XCTAssertEqual(game.rounds[0].orderIndex, 0)
        XCTAssertEqual(game.rounds[1].orderIndex, 1)
        XCTAssertEqual(game.rounds[2].orderIndex, 2)
    }
}

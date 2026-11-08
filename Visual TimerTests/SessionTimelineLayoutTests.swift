import XCTest
import SwiftUI
@testable import Visual_Timer

@MainActor
final class SessionTimelineLayoutTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000)

    private func record(_ events: [SessionEvent], colors: [String: RoundColor]? = nil) -> GameRecord {
        GameRecord(id: UUID(), gameTitle: "Night", session: GameSession(events: events),
                   playerNames: [], playedAt: t0, roundColors: colors)
    }

    private func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

    func testRoundsAreSizedByTheirShareOfTheSession() throws {
        let timeline = SessionTimeline(record: record([
            .gameStarted(timestamp: at(0)),
            .roundStarted(playerName: "Maya", emoji: "🦊", timestamp: at(0)),
            .roundFinished(playerName: "Maya", timestamp: at(30)),
            .roundStarted(playerName: "Theo", emoji: "🐢", timestamp: at(30)),
            .roundFinished(playerName: "Theo", timestamp: at(120)),
            .gameEnded(timestamp: at(120)),
        ]))

        XCTAssertEqual(timeline.span, 120)
        XCTAssertEqual(timeline.placement(of: timeline.items[0]), .init(start: 0, width: 0.25))
        XCTAssertEqual(timeline.placement(of: timeline.items[1]), .init(start: 0.25, width: 0.75))
        XCTAssertEqual(timeline.percent(of: timeline.items[1]), 75)
        XCTAssertNil(timeline.placement(of: timeline.items[2]), "The finish is an event, not a stretch")
    }

    func testPausesAreKeptAsStretchesInsideTheRound() {
        let timeline = SessionTimeline(record: record([
            .gameStarted(timestamp: at(0)),
            .roundStarted(playerName: "Maya", emoji: "🦊", timestamp: at(0)),
            .paused(timestamp: at(10)),
            .resumed(timestamp: at(25)),
            .paused(timestamp: at(40)),
            .gameEnded(timestamp: at(50)),
        ]))

        let maya = timeline.items[0]
        XCTAssertEqual(maya.pauses, [10..<25, 40..<50], "A pause still open at the end closes with the session")
        XCTAssertEqual(maya.note, "Session ended here · 2 pauses")
        XCTAssertEqual(timeline.fraction(at: 25), 0.5)
    }

    func testRoundsGetHeightByShareWithAFloor() {
        let timeline = SessionTimeline(record: record([
            .gameStarted(timestamp: at(0)),
            .roundStarted(playerName: "Maya", emoji: "", timestamp: at(0)),
            .roundStarted(playerName: "Theo", emoji: "", timestamp: at(95)),
            .gameEnded(timestamp: at(100)),
        ]))
        let heights = timeline.heights(total: 400, minimum: 56)
        XCTAssertEqual(heights[0], 380)
        XCTAssertEqual(heights[1], 56, "A short round still gets room for its label")
        XCTAssertNil(heights[2], "The finish is a moment, not a stretch")
    }

    func testPauseFractionsAreRelativeToTheRound() {
        let timeline = SessionTimeline(record: record([
            .gameStarted(timestamp: at(0)),
            .roundStarted(playerName: "Maya", emoji: "", timestamp: at(0)),
            .roundStarted(playerName: "Theo", emoji: "", timestamp: at(100)),
            .paused(timestamp: at(150)),
            .resumed(timestamp: at(175)),
            .gameEnded(timestamp: at(200)),
        ]))
        let theo = timeline.items[1]
        XCTAssertEqual(timeline.pauseFractions(of: theo), [0.5...0.75])
        XCTAssertEqual(theo.pausedSeconds, 25)
        XCTAssertEqual(theo.pauseCount, 1)
        XCTAssertEqual(theo.outcomeNote, "Session ended here")
    }

    func testWentBackSitsAtItsMomentOnTheTimeline() {
        let timeline = SessionTimeline(record: record([
            .gameStarted(timestamp: at(0)),
            .roundStarted(playerName: "Maya", emoji: "", timestamp: at(0)),
            .roundFinished(playerName: "Maya", timestamp: at(40)),
            .roundStarted(playerName: "Theo", emoji: "", timestamp: at(40)),
            .doOver(previousPlayer: "Maya", timestamp: at(50)),
            .roundStarted(playerName: "Maya", emoji: "", timestamp: at(50)),
            .roundFinished(playerName: "Maya", timestamp: at(100)),
            .gameEnded(timestamp: at(100)),
        ]))

        let back = timeline.items.first { $0.outcome == .wentBack }
        XCTAssertEqual(back.map { timeline.fraction(at: $0.startOffset) }, 0.5)
    }

    func testRecordsWithoutSavedColoursStillGetOneColourPerRound() {
        let events: [SessionEvent] = [
            .gameStarted(timestamp: at(0)),
            .roundStarted(playerName: "Maya", emoji: "", timestamp: at(0)),
            .roundStarted(playerName: "Theo", emoji: "", timestamp: at(10)),
            .roundStarted(playerName: "Maya", emoji: "", timestamp: at(20)),
            .gameEnded(timestamp: at(30)),
        ]
        let legacy = record(events)
        let timeline = SessionTimeline(record: legacy)
        let colors = timeline.items.map { timeline.color(for: $0, in: legacy) }

        XCTAssertNotNil(colors[0])
        XCTAssertEqual(colors[0], colors[2], "The same round keeps its colour")
        XCTAssertNotEqual(colors[0], colors[1])
        XCTAssertNil(colors[3], "Events get no colour")

        let saved = record(events, colors: ["Maya": .palette(index: 2)])
        XCTAssertEqual(SessionTimeline(record: saved).color(for: timeline.items[0], in: saved),
                       RoundColor.palette(index: 2).swiftUIColor)
    }

    func testFallbackColoursSkipSavedOnes() {
        let events: [SessionEvent] = [
            .gameStarted(timestamp: at(0)),
            .roundStarted(playerName: "Maya", emoji: "", timestamp: at(0)),
            .roundStarted(playerName: "Theo", emoji: "", timestamp: at(10)),
            .gameEnded(timestamp: at(20)),
        ]
        let partly = record(events, colors: ["Maya": .palette(index: 0)])
        let timeline = SessionTimeline(record: partly)
        XCTAssertNotEqual(timeline.color(for: timeline.items[0], in: partly),
                          timeline.color(for: timeline.items[1], in: partly))
    }

    func testANewPassStartsWhenTheFirstRoundComesUpAgain() {
        let timeline = SessionTimeline(record: record([
            .gameStarted(timestamp: at(0)),
            .roundStarted(playerName: "Maya", emoji: "", timestamp: at(0)),
            .roundStarted(playerName: "Theo", emoji: "", timestamp: at(10)),
            .doOver(previousPlayer: "Maya", timestamp: at(20)),
            .roundStarted(playerName: "Maya", emoji: "", timestamp: at(20)),
            .roundStarted(playerName: "Theo", emoji: "", timestamp: at(30)),
            .roundStarted(playerName: "Maya", emoji: "", timestamp: at(40)),
            .gameEnded(timestamp: at(50)),
        ]))
        // Items: Maya, Theo, went back, Maya (redo), Theo, Maya (pass 2), Finished.
        XCTAssertEqual(timeline.passStarts, [5], "Going back to Maya is a redo, not a new pass")
    }

    func testLengthsCarryTheirUnits() {
        XCTAssertEqual(TimerText.units(130), "2m 10s")
        XCTAssertEqual(TimerText.units(45), "45s")
        XCTAssertEqual(TimerText.units(540), "9m")
        XCTAssertEqual(TimerText.units(0), "0s")
        XCTAssertEqual(TimerText.units(3_605), "1h 5s")
    }

    func testEmptySessionHasNoTimeline() {
        let timeline = SessionTimeline(record: record([]))
        XCTAssertTrue(timeline.items.isEmpty)
        XCTAssertEqual(timeline.span, 0)
        XCTAssertFalse(timeline.hasRounds)
    }

    func testSessionWithNoTimeHasNothingToDivide() {
        let timeline = SessionTimeline(record: record([
            .gameStarted(timestamp: at(0)),
            .roundStarted(playerName: "Maya", emoji: "", timestamp: at(0)),
            .gameEnded(timestamp: at(0)),
        ]))
        XCTAssertFalse(timeline.hasRounds)
        XCTAssertNil(timeline.placement(of: timeline.items[0]))
    }
}

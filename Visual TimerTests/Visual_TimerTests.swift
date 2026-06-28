import CloudKit
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
        if case .palette(let index) = round.color {
            XCTAssertEqual(index, 0)
        } else {
            XCTFail("Expected default palette color")
        }
        XCTAssertEqual(round.sound, .chime)
        XCTAssertEqual(round.startPaused, false)
        XCTAssertEqual(round.isActive, true)
    }

    // MARK: - StarterTemplateLibrary

    func testStarterTemplateLibrary_containsPhaseOneTemplates() {
        let titles = StarterTemplateLibrary.templates.map(\.title)

        XCTAssertEqual(titles, [
            "Game Night",
            "Recipe Steps",
            "Plant Watering",
            "Classroom Stations",
            "Meeting Agenda",
        ])
    }

    func testStarterTemplateLibrary_gameNightHasPlayerTurnsAndTimeout() {
        let template = StarterTemplateLibrary.defaultTemplate
        let rounds = template.game.rounds

        XCTAssertEqual(template.title, "Game Night")
        XCTAssertEqual(template.game.roundCount, 1)
        XCTAssertEqual(rounds.map(\.name), ["Alice", "Bob", "Charlie", "Timeout"])
        XCTAssertEqual(rounds.map(\.countsAsPlayer), [true, true, true, false])
    }

    func testGameEditorViewModel_applyStarterTemplateReplacesCurrentDraft() {
        let editor = GameEditorViewModel()

        editor.addRound()
        editor.applyStarterTemplate(StarterTemplateLibrary.templates[1])

        XCTAssertEqual(editor.gameTitle, "Recipe Steps")
        XCTAssertEqual(editor.rounds.map(\.name), ["Prep", "Simmer", "Flip or Stir", "Rest"])
        XCTAssertEqual(editor.roundCount, 1)
        XCTAssertNil(editor.expandedRoundId)
    }

    // MARK: - TemplateSavePolicy

    func testTemplateSavePolicy_freeAllowsFirstTemplate() {
        XCTAssertTrue(TemplateSavePolicy.canSaveTemplate(
            isProUnlocked: false,
            lastSavedFileName: "",
            proposedFileName: "Game Night.vtgame"
        ))
    }

    func testTemplateSavePolicy_freeAllowsOverwritingExistingTemplate() {
        XCTAssertTrue(TemplateSavePolicy.canSaveTemplate(
            isProUnlocked: false,
            lastSavedFileName: "Game Night.vtgame",
            proposedFileName: "Game Night.vtgame"
        ))
    }

    func testTemplateSavePolicy_freeBlocksSecondTemplate() {
        XCTAssertFalse(TemplateSavePolicy.canSaveTemplate(
            isProUnlocked: false,
            lastSavedFileName: "Game Night.vtgame",
            proposedFileName: "Recipe Steps.vtgame"
        ))
    }

    func testTemplateSavePolicy_proAllowsSecondTemplate() {
        XCTAssertTrue(TemplateSavePolicy.canSaveTemplate(
            isProUnlocked: true,
            lastSavedFileName: "Game Night.vtgame",
            proposedFileName: "Recipe Steps.vtgame"
        ))
    }

    func testTemplateSavePolicy_freeAllowsUpdatingExistingTurnTimerTemplate() {
        XCTAssertTrue(TemplateSavePolicy.canSaveTemplate(
            isProUnlocked: false,
            existingTemplateCount: 1,
            isUpdatingExistingTemplate: true
        ))
    }

    func testTemplateSavePolicy_freeBlocksSecondTurnTimerTemplate() {
        XCTAssertFalse(TemplateSavePolicy.canSaveTemplate(
            isProUnlocked: false,
            existingTemplateCount: 1,
            isUpdatingExistingTemplate: false
        ))
    }

    // MARK: - TurnTimerTemplateDocument

    func testTemplateDocumentCodec_roundTripPreservesGame() throws {
        let game = makeTemplateGame(title: "Recipe Steps")
        let document = TurnTimerTemplateDocument(
            templateID: UUID(uuidString: "75DA13FA-8842-4D1C-B9E4-648F36D5B013")!,
            title: "Recipe Steps",
            game: game,
            createdAt: Date(timeIntervalSince1970: 1_000),
            modifiedAt: Date(timeIntervalSince1970: 2_000),
            exportedAt: Date(timeIntervalSince1970: 3_000)
        )

        let codec = TemplateDocumentCodec()
        let data = try codec.encode(document)
        let decoded = try codec.decode(data)

        XCTAssertEqual(decoded.templateID, document.templateID)
        XCTAssertEqual(decoded.title, "Recipe Steps")
        XCTAssertEqual(decoded.game.rounds.map(\.name), ["Prep", "Cook"])
        XCTAssertEqual(decoded.game.rounds.map(\.durationSeconds), [60, 300])
    }

    func testTemplateLibraryStore_importTemplateDuplicatesWithoutOverwriting() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = TemplateLibraryStore(documentsDirectory: directory)
        let saved = try store.save(game: makeTemplateGame(title: "Game Night"))
        let incoming = TurnTimerTemplateDocument(title: "Game Night", game: makeTemplateGame(title: "Game Night"))

        let imported = try store.importTemplate(incoming)
        let templates = store.listTemplates()

        XCTAssertNotEqual(imported.id, saved.id)
        XCTAssertEqual(imported.title, "Game Night Copy")
        XCTAssertEqual(templates.count, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported.url.path))
    }

    func testTemplateLibraryStore_migratesLegacyVTGameToTurnTimerFile() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let legacyURL = directory.appendingPathComponent("Legacy.vtgame")
        let legacyContent = GameFileParser().serialize(makeTemplateGame(title: "Legacy Template"))
        try legacyContent.write(to: legacyURL, atomically: true, encoding: .utf8)

        let store = TemplateLibraryStore(documentsDirectory: directory)
        let migrated = try XCTUnwrap(store.migrateLegacyTemplateIfNeeded(fileName: "Legacy.vtgame"))
        let document = try store.loadDocument(id: migrated.id)

        XCTAssertEqual(migrated.title, "Legacy Template")
        XCTAssertEqual(migrated.url.pathExtension, "turntimer")
        XCTAssertEqual(document.game.rounds.map(\.name), ["Prep", "Cook"])
    }

    func testTemplateCloudRecordMapper_roundTripPreservesTemplatePayload() throws {
        let game = makeTemplateGame(title: "Synced Template")
        let document = TurnTimerTemplateDocument(title: "Synced Template", game: game)
        let mapper = TemplateCloudRecordMapper()

        let record = try mapper.record(from: document)
        let decoded = try mapper.document(from: record)

        XCTAssertEqual(record.recordType, TemplateSyncConfiguration.recordType)
        XCTAssertEqual(decoded.templateID, document.templateID)
        XCTAssertEqual(decoded.title, "Synced Template")
        XCTAssertEqual(decoded.game.rounds.map(\.name), ["Prep", "Cook"])
    }

    func testCloudKitValidationReportSummarizesFailures() {
        let report = CloudKitValidationReport(checks: [
            .init(name: "Account", status: .passed, detail: "Available"),
            .init(name: "Probe", status: .failed, detail: "Missing Template schema"),
        ])

        XCTAssertFalse(report.isReadyForRelease)
        XCTAssertEqual(report.failedChecks.map(\.name), ["Probe"])
    }

    // MARK: - HistoryAccessPolicy

    func testHistoryAccessPolicy_freeLimitsRecords() {
        let records = makeHistoryRecords(count: 7)

        let visible = HistoryAccessPolicy.visibleRecords(records, isProUnlocked: false)

        XCTAssertEqual(visible.count, HistoryAccessPolicy.freeRecordLimit)
        XCTAssertTrue(HistoryAccessPolicy.isLimited(records: records, isProUnlocked: false))
    }

    func testHistoryAccessPolicy_proShowsAllRecords() {
        let records = makeHistoryRecords(count: 7)

        let visible = HistoryAccessPolicy.visibleRecords(records, isProUnlocked: true)

        XCTAssertEqual(visible.count, 7)
        XCTAssertFalse(HistoryAccessPolicy.isLimited(records: records, isProUnlocked: true))
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

    private func makeTemplateGame(title: String) -> GameSequence {
        var game = GameSequence(title: title, roundCount: 1)
        game.rounds = [
            Round(name: "Prep", durationSeconds: 60, orderIndex: 0),
            Round(name: "Cook", durationSeconds: 300, orderIndex: 1),
        ]
        game.reindexRounds()
        return game
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VisualTimerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeHistoryRecords(count: Int) -> [GameRecord] {
        (0..<count).map { index in
            GameRecord(
                id: UUID(),
                gameTitle: "Session \(index)",
                session: GameSession(events: []),
                playerNames: [],
                playedAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
    }
}

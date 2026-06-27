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

    func testGameEditorViewModel_applySavedTemplateByIDLoadsStoredTemplate() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = TemplateLibraryStore(documentsDirectory: directory)
        var game = makeTemplateGame(title: "Stored Template")
        game.roundCount = 3
        let saved = try store.save(game: game)
        let editor = GameEditorViewModel(templateLibrary: store)

        let result = editor.applySavedTemplate(id: saved.id)

        XCTAssertTrue(result.0, "Unexpected load errors: \(result.1.map(\.message))")
        XCTAssertEqual(editor.gameTitle, "Stored Template")
        XCTAssertEqual(editor.rounds.map(\.name), ["Prep", "Cook"])
        XCTAssertEqual(editor.roundCount, 3)
        XCTAssertEqual(editor.currentSavedTemplateID, saved.id)
    }

    func testGameEditorViewModel_applySavedTemplateByIDReportsMissingTemplate() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = TemplateLibraryStore(documentsDirectory: directory)
        let editor = GameEditorViewModel(templateLibrary: store)

        let result = editor.applySavedTemplate(id: UUID())

        XCTAssertFalse(result.0)
        XCTAssertEqual(result.1.first?.message, "Template not found.")
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

    func testTemplateLibraryStore_snapshotSummarizesTemplateForWidgets() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = TemplateLibraryStore(documentsDirectory: directory)
        let saved = try store.save(game: makeTemplateGame(title: "Widget Template"))

        let snapshot = try store.snapshot(for: saved)

        XCTAssertEqual(snapshot.id, saved.id.uuidString)
        XCTAssertEqual(snapshot.title, "Widget Template")
        XCTAssertEqual(snapshot.subtitle, "2 rounds • once")
        XCTAssertEqual(snapshot.roundCount, 2)
        XCTAssertEqual(snapshot.repeatCount, 1)
        XCTAssertEqual(snapshot.firstRoundName, "Prep")
        XCTAssertEqual(snapshot.firstRoundDurationSeconds, 60)
        XCTAssertEqual(snapshot.totalDurationSeconds, 360)
    }

    func testTemplateWidgetStore_consumesPendingStartRequestOnce() throws {
        let defaults = try makeIsolatedUserDefaults()
        let store = TemplateWidgetStore(userDefaults: defaults)

        store.writePendingStart(templateID: "template-id")

        XCTAssertEqual(store.consumePendingStartTemplateID(), "template-id")
        XCTAssertNil(store.consumePendingStartTemplateID())
    }

    func testTemplateWidgetStore_roundTripsPayload() throws {
        let defaults = try makeIsolatedUserDefaults()
        let store = TemplateWidgetStore(userDefaults: defaults)
        let snapshot = TemplateWidgetSnapshot(
            id: "favorite-id",
            title: "Game Night",
            subtitle: "4 rounds • once",
            roundCount: 4,
            repeatCount: 1,
            firstRoundName: "Alice",
            firstRoundDurationSeconds: 60,
            totalDurationSeconds: 300,
            modifiedAt: Date(timeIntervalSince1970: 10)
        )
        let payload = TemplateWidgetPayload(
            favoriteTemplateID: "favorite-id",
            templates: [snapshot],
            generatedAt: Date(timeIntervalSince1970: 20)
        )

        store.writePayload(payload)

        XCTAssertEqual(store.readPayload(), payload)
        XCTAssertEqual(store.readPayload().favoriteTemplate, snapshot)
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

    private func makeIsolatedUserDefaults() throws -> UserDefaults {
        let suiteName = "VisualTimerTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
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

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

    // MARK: - TurnTimerDeepLink

    @MainActor
    func testTurnTimerDeepLinkParsesSavedTemplateURL() throws {
        let id = UUID()
        let link = try XCTUnwrap(TurnTimerDeepLink(url: URL(string: "turntimer://template/\(id.uuidString)")!))

        XCTAssertEqual(link, .template(id))
    }

    @MainActor
    func testTurnTimerDeepLinkParsesStarterTemplateURL() throws {
        let link = try XCTUnwrap(TurnTimerDeepLink(url: URL(string: "turntimer://starter/game-night")!))

        XCTAssertEqual(link, .starter("game-night"))
    }

    // MARK: - WidgetSnapshotStore

    func testWidgetSnapshotStoreWritesStarterAndSavedTemplateMetadata() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let savedTemplateID = UUID(uuidString: "E80D978E-C9F9-4F1A-89DA-A1126FF69272")!
        let savedURL = directory
            .appendingPathComponent("Templates", isDirectory: true)
            .appendingPathComponent("\(savedTemplateID.uuidString).turntimer")
        let savedTemplate = SavedTemplate(
            id: savedTemplateID,
            title: "Saved Game",
            roundCount: 2,
            repeatCount: 3,
            totalSeconds: 480,
            modifiedAt: Date(timeIntervalSince1970: 2_000),
            url: savedURL
        )
        let store = WidgetSnapshotStore(
            containerURLProvider: { directory },
            dateProvider: { Date(timeIntervalSince1970: 1_000) }
        )

        try store.writeSnapshots(savedTemplates: [savedTemplate], isProUnlocked: true)

        let snapshots = try store.readSnapshots()
        XCTAssertEqual(snapshots.count, StarterTemplateLibrary.templates.count + 1)

        let starterSnapshot = try XCTUnwrap(snapshots.first)
        XCTAssertEqual(starterSnapshot.id, "game-night")
        XCTAssertEqual(starterSnapshot.source, .starter)
        XCTAssertEqual(starterSnapshot.starterID, "game-night")
        XCTAssertNil(starterSnapshot.templateID)
        XCTAssertEqual(starterSnapshot.totalSeconds, 300)
        XCTAssertEqual(starterSnapshot.roundCount, 4)
        XCTAssertEqual(starterSnapshot.modifiedAt, Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(starterSnapshot.launchURL, URL(string: "turntimer://starter/game-night")!)

        let savedSnapshot = try XCTUnwrap(snapshots.last)
        XCTAssertEqual(savedSnapshot.id, savedTemplateID.uuidString)
        XCTAssertEqual(savedSnapshot.title, "Saved Game")
        XCTAssertEqual(savedSnapshot.subtitle, "2 rounds • 3x")
        XCTAssertEqual(savedSnapshot.source, .saved)
        XCTAssertEqual(savedSnapshot.templateID, savedTemplateID)
        XCTAssertNil(savedSnapshot.starterID)
        XCTAssertEqual(savedSnapshot.totalSeconds, 480)
        XCTAssertEqual(savedSnapshot.roundCount, 2)
        XCTAssertEqual(savedSnapshot.modifiedAt, Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(savedSnapshot.launchURL, URL(string: "turntimer://template/\(savedTemplateID.uuidString)")!)

        let data = try Data(contentsOf: directory.appendingPathComponent("WidgetTemplates.json"))
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains(savedURL.path))
    }

    func testWidgetSnapshotStoreReadsEmptySnapshotsWhenFileIsMissing() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WidgetSnapshotStore(containerURLProvider: { directory })

        XCTAssertEqual(try store.readSnapshots(), [])
    }

    func testWidgetSnapshotStoreWritesLockedSnapshotWhenProUnavailable() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let savedTemplate = SavedTemplate(
            id: UUID(),
            title: "Saved Game",
            roundCount: 2,
            repeatCount: 1,
            totalSeconds: 120,
            modifiedAt: Date(timeIntervalSince1970: 2_000),
            url: directory.appendingPathComponent("Saved.turntimer")
        )
        let store = WidgetSnapshotStore(containerURLProvider: { directory })

        try store.writeSnapshots(savedTemplates: [savedTemplate], isProUnlocked: false)

        let snapshots = try store.readSnapshots()
        XCTAssertEqual(snapshots.count, 1)
        let locked = try XCTUnwrap(snapshots.first)
        XCTAssertEqual(locked.source, .locked)
        XCTAssertEqual(locked.title, "Turn Timer Pro")
        XCTAssertEqual(locked.launchURL, URL(string: "turntimer://pro")!)
    }

    func testWidgetTemplateSelectionFiltersLockedPlaceholders() {
        let saved = WidgetTemplateSnapshot(
            id: "saved-template",
            title: "Saved Game",
            subtitle: "1 round",
            source: .saved,
            templateID: UUID(),
            starterID: nil,
            totalSeconds: 60,
            roundCount: 1,
            modifiedAt: Date(timeIntervalSince1970: 1_000)
        )

        let selectable = WidgetTemplateSnapshot.selectableSnapshots(from: [
            .proLocked,
            saved,
        ])

        XCTAssertEqual(selectable.map(\.id), [saved.id])
    }

    func testGameEditorViewModelPublishesLockedWidgetSnapshotsUntilProEnabled() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let documentsDirectory = directory.appendingPathComponent("Documents", isDirectory: true)
        let appGroupDirectory = directory.appendingPathComponent("AppGroup", isDirectory: true)
        let templateLibrary = TemplateLibraryStore(documentsDirectory: documentsDirectory)
        _ = try templateLibrary.save(game: makeTemplateGame(title: "Pro Game"))
        let snapshotStore = WidgetSnapshotStore(
            containerURLProvider: { appGroupDirectory },
            dateProvider: { Date(timeIntervalSince1970: 3_000) }
        )
        let viewModel = GameEditorViewModel(
            templateLibrary: templateLibrary,
            widgetSnapshotStore: snapshotStore
        )

        viewModel.refreshSavedTemplates()

        XCTAssertEqual(try snapshotStore.readSnapshots().map(\.source), [.locked])

        viewModel.setWidgetPublishingEnabled(true)

        let unlockedSnapshots = try snapshotStore.readSnapshots()
        XCTAssertFalse(unlockedSnapshots.contains { $0.source == .locked })
        XCTAssertTrue(unlockedSnapshots.contains { $0.title == "Pro Game" })
    }

    func testWidgetTemplateSnapshotFormatsStaticDurationText() {
        let snapshot = WidgetTemplateSnapshot(
            id: "saved-template",
            title: "Saved Game",
            subtitle: "2 rounds",
            source: .saved,
            templateID: UUID(),
            starterID: nil,
            totalSeconds: 4_800,
            roundCount: 2,
            modifiedAt: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertEqual(snapshot.durationText, "1:20:00")
    }

    func testWidgetTemplateSnapshotFormatsRoundCountText() {
        var snapshot = WidgetTemplateSnapshot(
            id: "saved-template",
            title: "Saved Game",
            subtitle: "1 round",
            source: .saved,
            templateID: UUID(),
            starterID: nil,
            totalSeconds: 60,
            roundCount: 1,
            modifiedAt: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertEqual(snapshot.roundCountText, "1 round")

        snapshot.roundCount = 2
        XCTAssertEqual(snapshot.roundCountText, "2 rounds")
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

    func testHistoryCloudRecordMapper_roundTripPreservesHistoryPayload() throws {
        let record = makeHistoryRecords(count: 1)[0]
        let document = HistoryDocument(record: record, modifiedAt: Date(timeIntervalSince1970: 2_000))
        let mapper = HistoryCloudRecordMapper()

        let cloudRecord = try mapper.record(from: document)
        let decoded = try mapper.document(from: cloudRecord)

        XCTAssertEqual(cloudRecord.recordType, HistorySyncConfiguration.recordType)
        XCTAssertEqual(decoded.record.id, record.id)
        XCTAssertEqual(decoded.record.gameTitle, record.gameTitle)
        XCTAssertEqual(decoded.record.session.events.count, record.session.events.count)
    }

    func testHistorySyncConfigurationDefersCloudKitContainerCreation() {
        let configuration = HistorySyncConfiguration(containerIdentifier: "iCloud.Test.Container")
        let storedPropertyLabels = Set(Mirror(reflecting: configuration).children.compactMap(\.label))

        XCTAssertTrue(storedPropertyLabels.contains("containerIdentifier"))
        XCTAssertFalse(storedPropertyLabels.contains("container"))
    }

    @MainActor
    func testHistoryCloudSyncEnginePersistsDeletedHistoryIDsAcrossRelaunch() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let suiteName = "VisualTimerTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstDeletedID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let secondDeletedID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let store = HistoryStore(documentsDirectory: directory)
        let engine = HistoryCloudSyncEngine(
            historyStore: store,
            configuration: HistorySyncConfiguration(),
            userDefaults: defaults
        )

        engine.queueDeletedHistory(id: firstDeletedID)

        XCTAssertEqual(
            Set(defaults.stringArray(forKey: HistorySyncConfiguration.pendingDeletedHistoryIDsKey) ?? []),
            [firstDeletedID.uuidString]
        )

        let relaunchedEngine = HistoryCloudSyncEngine(
            historyStore: store,
            configuration: HistorySyncConfiguration(),
            userDefaults: defaults
        )
        relaunchedEngine.queueDeletedHistory(id: secondDeletedID)

        XCTAssertEqual(
            Set(defaults.stringArray(forKey: HistorySyncConfiguration.pendingDeletedHistoryIDsKey) ?? []),
            [firstDeletedID.uuidString, secondDeletedID.uuidString]
        )
    }

    @MainActor
    func testHistoryCloudSyncEngineClearsUnknownItemDeleteTombstone() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let suiteName = "VisualTimerTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let deletedID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let store = HistoryStore(documentsDirectory: directory)
        let engine = HistoryCloudSyncEngine(
            historyStore: store,
            configuration: HistorySyncConfiguration(),
            userDefaults: defaults
        )
        let recordID = HistoryCloudRecordMapper().recordID(for: deletedID)

        engine.queueDeletedHistory(id: deletedID)
        let result = engine.handleSentDeletedRecordResults(
            deletedRecordIDs: [],
            failedRecordDeletes: [recordID: CKError(.unknownItem)]
        )

        XCTAssertEqual(result.confirmedRecordIDs.map(\.recordName), [deletedID.uuidString])
        XCTAssertFalse(result.hasRetryableFailures)
        XCTAssertEqual(defaults.stringArray(forKey: HistorySyncConfiguration.pendingDeletedHistoryIDsKey), [])
    }

    @MainActor
    func testHistoryCloudSyncEngineDoesNotApplyRemoteModificationForPendingDelete() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let suiteName = "VisualTimerTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let deletedID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let store = HistoryStore(documentsDirectory: directory)
        var localRecord = makeHistoryRecords(count: 1)[0]
        localRecord.id = deletedID
        store.save(localRecord)
        let engine = HistoryCloudSyncEngine(
            historyStore: store,
            configuration: HistorySyncConfiguration(),
            userDefaults: defaults
        )
        engine.queueDeletedHistory(id: deletedID)
        store.delete(id: deletedID)

        var remoteRecord = localRecord
        remoteRecord.gameTitle = "Remote Resurrection"
        let didApply = engine.applyFetchedHistoryDocument(
            HistoryDocument(record: remoteRecord, modifiedAt: Date(timeIntervalSince1970: 10_000))
        )

        XCTAssertTrue(didApply)
        XCTAssertNil(store.load(id: deletedID))
        XCTAssertEqual(
            defaults.stringArray(forKey: HistorySyncConfiguration.pendingDeletedHistoryIDsKey),
            [deletedID.uuidString]
        )
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

    func testHistoryStore_saveDocumentCanLoadRecordFromInjectedDirectory() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HistoryStore(documentsDirectory: directory)
        let record = makeHistoryRecords(count: 1)[0]
        let document = HistoryDocument(record: record, modifiedAt: Date(timeIntervalSince1970: 2_000))

        store.save(document: document)

        let loaded = try XCTUnwrap(store.load(id: record.id))
        XCTAssertEqual(loaded.id, record.id)
        XCTAssertEqual(loaded.gameTitle, record.gameTitle)
        let loadedDocument = try XCTUnwrap(store.loadDocument(id: record.id))
        XCTAssertEqual(loadedDocument.modifiedAt.timeIntervalSince1970, 2_000, accuracy: 1)
        XCTAssertEqual(store.loadAll().map(\.id), [record.id])
    }

    func testHistoryStoreExportURLSanitizesRecordTitle() throws {
        let store = HistoryStore()
        var record = makeHistoryRecords(count: 1)[0]
        record.gameTitle = "A/B:C"

        let url = try XCTUnwrap(store.exportURL(for: record))
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(url.lastPathComponent, "A-B-C.vtlog")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testHistoryViewModelLoadsRecordsFromInjectedStore() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HistoryStore(documentsDirectory: directory)
        let record = makeHistoryRecords(count: 1)[0]
        store.save(record)

        let viewModel = HistoryViewModel(store: store)

        XCTAssertEqual(viewModel.records.map(\.id), [record.id])
    }

    func testHistoryViewModelNotifiesDeletedRecord() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HistoryStore(documentsDirectory: directory)
        let record = makeHistoryRecords(count: 1)[0]
        store.save(record)
        let viewModel = HistoryViewModel(store: store)
        var deletedIDs: [UUID] = []
        viewModel.onRecordDeleted = { deletedIDs.append($0) }

        viewModel.deleteRecord(id: record.id)

        XCTAssertEqual(deletedIDs, [record.id])
        XCTAssertTrue(viewModel.records.isEmpty)
        XCTAssertNil(store.load(id: record.id))
    }

    func testGameViewModelSavesCompletedSessionThroughInjectedHistoryStore() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HistoryStore(documentsDirectory: directory)
        var savedIDs: [UUID] = []
        let gameViewModel = GameViewModel(
            timerViewModel: TimerViewModel(),
            historyStore: store,
            onHistoryRecordSaved: { savedIDs.append($0.id) }
        )

        gameViewModel.loadGame(makeTemplateGame(title: "Tracked Session"))
        gameViewModel.startGame()
        gameViewModel.endGame()

        let records = store.loadAll()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(savedIDs, records.map(\.id))
        XCTAssertEqual(records.first?.gameTitle, "Tracked Session")
    }

    @MainActor
    func testTimerViewModelSetDurationClampsToMinimumDuration() {
        UserDefaults.standard.removeObject(forKey: "savedTimerDuration")
        let viewModel = TimerViewModel()

        viewModel.setDuration(0)

        XCTAssertEqual(viewModel.totalDuration, Theme.TimerMechanic.minimumDuration)
        XCTAssertEqual(viewModel.timeRemaining, Theme.TimerMechanic.minimumDuration)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "savedTimerDuration"), Theme.TimerMechanic.minimumDuration)
        UserDefaults.standard.removeObject(forKey: "savedTimerDuration")
    }

    @MainActor
    func testProAccessRefreshResetsPurchaseStateWhenEntitlementIsRevoked() {
        let proAccess = ProAccessViewModel(automaticallyStartsStoreKitTasks: false)

        proAccess.applyEntitlementRefreshResult(isUnlocked: true)
        proAccess.applyEntitlementRefreshResult(isUnlocked: false)

        XCTAssertFalse(proAccess.isProUnlocked)
        XCTAssertEqual(proAccess.purchaseState, .idle)
    }

    func testTurnTimerCountTextUsesSingularForOne() {
        XCTAssertEqual(TurnTimerCountText.label(for: 1, singular: "round"), "1 round")
        XCTAssertEqual(TurnTimerCountText.label(for: 2, singular: "round"), "2 rounds")
        XCTAssertEqual(TurnTimerCountText.label(for: 1, singular: "do-over"), "1 do-over")
        XCTAssertEqual(TurnTimerCountText.label(for: 2, singular: "do-over"), "2 do-overs")
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

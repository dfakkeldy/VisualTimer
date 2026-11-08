import XCTest
@testable import Visual_Timer

@MainActor
final class StopwatchTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    private func source(templateID: UUID = UUID(), targets: [Int?] = [30, 60, 15]) -> StopwatchSource {
        StopwatchSource(templateID: templateID, title: "Morning routine", steps: targets.enumerated().map {
            .init(id: UUID(), name: ["Prepare", "Focus", "Rest"][$0.offset % 3], targetSeconds: $0.element)
        })
    }

    private func recording(source: StopwatchSource, durations: [Double], date: Date? = nil) -> StopwatchRecording {
        StopwatchRecording(version: StopwatchRecording.schemaVersion, id: UUID(), source: source,
            startedAt: date ?? epoch, finishedAt: (date ?? epoch).addingTimeInterval(durations.reduce(0, +)),
            measurements: zip(source.steps, durations).map { .init(stepID: $0.0.id, seconds: $0.1) })
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("StopwatchTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }

    func testCountsBackgroundTimeWithoutTicksAndExcludesMultiplePauses() throws {
        var session = StopwatchSession(source: source())
        try session.start(at: 100, date: epoch)
        XCTAssertEqual(session.elapsed(at: 700), 600) // no UI refresh required
        session.pause(at: 710)
        XCTAssertEqual(session.elapsed(at: 9_000), 610)
        session.pause(at: 9_000) // repeated pause must not add time
        session.resume(at: 10_000)
        session.resume(at: 20_000) // repeated resume must not reset the anchor
        XCTAssertEqual(session.elapsed(at: 10_005), 615)
        session.pause(at: 10_005)
        session.resume(at: 30_000)
        session.finish(expectedStepID: session.source.steps[0].id, at: 30_008, date: epoch.addingTimeInterval(99_999))
        XCTAssertEqual(session.recording?.measurements.first?.seconds, 623)
        XCTAssertEqual(session.recording?.startedAt, epoch)
    }

    func testNextCompletesCurrentAndStartsNextAndRejectsStaleTap() throws {
        let source = source()
        var session = StopwatchSession(source: source)
        try session.start(at: 0, date: epoch)
        session.next(expectedStepID: source.steps[0].id, at: 12.25, date: epoch)
        session.next(expectedStepID: source.steps[0].id, at: 12.3, date: epoch)
        session.next(expectedStepID: source.steps[1].id, at: 12.4, date: epoch)
        XCTAssertEqual(session.index, 1, "A rapid second tap must not skip the newly displayed step")
        XCTAssertEqual(session.measurements.map(\.seconds), [12.25])
        XCTAssertEqual(session.elapsed(at: 15), 2.75)
        session.pause(at: 16)
        session.next(expectedStepID: source.steps[1].id, at: 100, date: epoch)
        XCTAssertEqual(session.phase, .running)
        XCTAssertEqual(session.measurements.map(\.seconds), [12.25, 3.75])
        session.next(expectedStepID: source.steps[2].id, at: 109, date: epoch)
        XCTAssertEqual(session.phase, .review)
        XCTAssertEqual(session.recording?.measurements.map(\.seconds), [12.25, 3.75, 9])
        XCTAssertTrue(session.recording?.isComplete == true)
        let finished = session.recording
        session.next(expectedStepID: source.steps[2].id, at: 500, date: epoch)
        session.finish(expectedStepID: source.steps[2].id, at: 500, date: epoch)
        session.resume(at: 500)
        try session.start(at: 500, date: epoch)
        XCTAssertEqual(session.recording, finished)
    }

    func testFinishWhilePausedProducesPartialRecordingAndDoesNotCountFutureSteps() throws {
        let source = source()
        var session = StopwatchSession(source: source)
        try session.start(at: 0, date: epoch)
        session.pause(at: 7)
        session.finish(expectedStepID: source.steps[0].id, at: 90, date: epoch)
        let record = try XCTUnwrap(session.recording)
        XCTAssertEqual(record.measurements.map(\.seconds), [7])
        XCTAssertFalse(record.isComplete)
        XCTAssertEqual(record.source.steps.count, 3)
        XCTAssertNoThrow(try record.validate())
    }

    func testInvalidTransitionsAndDiscardHaveNoMeasurements() throws {
        let source = source()
        var session = StopwatchSession(source: source)
        session.pause(at: 1)
        session.resume(at: 1)
        session.next(expectedStepID: source.steps[0].id, at: 1, date: epoch)
        session.finish(expectedStepID: source.steps[0].id, at: 1, date: epoch)
        XCTAssertEqual(session.phase, .ready)
        try session.start(at: 1, date: epoch)
        session.discard()
        session.discard()
        session.resume(at: 9)
        try session.start(at: 10, date: epoch)
        XCTAssertEqual(session.phase, .discarded)
        XCTAssertTrue(session.measurements.isEmpty)
        XCTAssertNil(session.recording)
    }

    func testFiniteClockGuardsAndDurationCap() throws {
        let source = source(targets: [nil])
        var session = StopwatchSession(source: source)
        XCTAssertThrowsError(try session.start(at: .nan, date: epoch))
        try session.start(at: 100, date: epoch)
        XCTAssertEqual(session.elapsed(at: .infinity), 0)
        session.next(expectedStepID: source.steps[0].id, at: .nan, date: epoch)
        XCTAssertEqual(session.phase, .running)
        XCTAssertEqual(session.elapsed(at: 50), 0)
        XCTAssertEqual(session.elapsed(at: 1_000_000), StopwatchLimits.maximumStepSeconds)
        session.finish(expectedStepID: source.steps[0].id, at: 1_000_000, date: epoch)
        XCTAssertNoThrow(try session.recording?.validate())
        XCTAssertEqual(session.recording?.measurements.first?.templateSeconds, 86_400)
    }

    func testNoTargetSnapshotAndRoundingToExistingMinimum() throws {
        let source = source(targets: [nil, nil, nil])
        let record = recording(source: source, durations: [0.2, 7.6, 9.4])
        try record.validate()
        XCTAssertEqual(record.source.steps.map(\.targetSeconds), [nil, nil, nil])
        XCTAssertEqual(record.measurements.map(\.templateSeconds), [5, 8, 9])
    }

    func testValidationRejectsDuplicateIDsNonFiniteMeasurementsAndFutureFormats() throws {
        let source = source()
        let duplicateSource = StopwatchSource(templateID: source.templateID, title: source.title,
            steps: [source.steps[0], source.steps[0]])
        XCTAssertThrowsError(try duplicateSource.validate())
        XCTAssertThrowsError(try recording(source: source, durations: [.nan]).validate())
        XCTAssertThrowsError(try recording(source: source, durations: [.infinity]).validate())
        XCTAssertThrowsError(try recording(source: source, durations: [-1]).validate())
        XCTAssertThrowsError(try recording(source: source, durations: [86_401]).validate())
        let record = recording(source: source, durations: [10])
        let future = StopwatchRecording(version: 99, id: record.id, source: source,
            startedAt: record.startedAt, finishedAt: record.finishedAt, measurements: record.measurements)
        XCTAssertThrowsError(try future.validate())
        let outOfOrder = StopwatchRecording(version: 1, id: UUID(), source: source,
            startedAt: epoch, finishedAt: epoch,
            measurements: [.init(stepID: source.steps[1].id, seconds: 10)])
        XCTAssertThrowsError(try outOfOrder.validate())
    }

    func testPersistenceRoundTripIsolationIdempotentRetryAndDeletion() throws {
        let directory = try temporaryDirectory()
        let store = StopwatchRecordingStore(directory: directory)
        let source = source()
        let record = recording(source: source, durations: [32.125, 50.75, 10])
        let copiedSource = StopwatchSource(templateID: UUID(), title: source.title, steps: source.steps)
        let unrelated = recording(source: copiedSource, durations: [14])
        try store.save(record)
        try store.save(record)
        try store.save(unrelated)
        let loaded = try store.load(templateID: source.templateID)
        XCTAssertEqual(loaded.records, [record])
        XCTAssertTrue(loaded.unreadableFiles.isEmpty)
        XCTAssertEqual(try store.load(templateID: unrelated.source.templateID).records, [unrelated])
        try store.delete(id: record.id)
        XCTAssertTrue(try store.load(templateID: source.templateID).records.isEmpty)
        XCTAssertEqual(try store.load(templateID: unrelated.source.templateID).records, [unrelated])
    }

    func testMalformedFileReportedAndPreservedAlongsideReadableRecords() throws {
        let directory = try temporaryDirectory()
        let store = StopwatchRecordingStore(directory: directory)
        let record = recording(source: source(), durations: [12])
        try store.save(record)
        let malformed = directory.appendingPathComponent("broken.json")
        try Data("not a recording".utf8).write(to: malformed)
        let loaded = try store.load(templateID: record.source.templateID)
        XCTAssertEqual(loaded.records, [record])
        XCTAssertEqual(loaded.unreadableFiles, ["broken.json"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: malformed.path))
    }

    func testStoreSaveAndLoadErrorsAreThrown() throws {
        let directory = try temporaryDirectory()
        let file = directory.appendingPathComponent("file")
        try Data().write(to: file)
        let store = StopwatchRecordingStore(directory: file)
        XCTAssertThrowsError(try store.save(recording(source: source(), durations: [1])))
        XCTAssertThrowsError(try store.load(templateID: UUID()))
    }

    func testViewModelSnapshotsTargetsAndBuildsTrendByStepIdentity() throws {
        let store = MemoryStopwatchStore()
        let clock = TestClock()
        let source = source()
        let model = viewModel(source: source, store: store, clock: clock)
        model.start()
        clock.time = 11
        model.next(stepID: source.steps[0].id)
        clock.time = 20
        model.finish(stepID: source.steps[1].id)
        XCTAssertEqual(model.reviewRecord?.source, source)
        XCTAssertTrue(model.saveReview())
        let oldRecord = try XCTUnwrap(model.reviewRecord)
        var modifiedSteps = source.steps
        modifiedSteps[0] = .init(id: source.steps[0].id, name: "Renamed", targetSeconds: 90)
        modifiedSteps[1] = .init(id: UUID(), name: "Focus", targetSeconds: 999)
        let edited = StopwatchSource(templateID: source.templateID, title: "Changed", steps: modifiedSteps)
        let second = StopwatchViewModel(source: edited, isProUnlocked: true, store: store, automaticallyRefresh: false)
        second.selectedTrendStepID = source.steps[0].id
        XCTAssertEqual(second.trendPoints.map(\.step.targetSeconds), [30])
        XCTAssertEqual(second.trendPoints.map(\.step.name), ["Prepare"])
        second.selectedTrendStepID = modifiedSteps[1].id
        XCTAssertTrue(second.trendPoints.isEmpty, "Matching names cannot join different step identities")
        XCTAssertEqual(store.records.first, oldRecord)
    }

    func testSaveFailureKeepsReviewAndPreventsApplyUntilRetry() throws {
        let store = MemoryStopwatchStore()
        let clock = TestClock()
        let source = source()
        let model = viewModel(source: source, store: store, clock: clock)
        model.start()
        clock.time = 10
        model.finish(stepID: source.steps[0].id)
        store.failSave = true
        var applied = false
        XCTAssertFalse(model.applyReview { _ in applied = true })
        XCTAssertFalse(applied)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertNotNil(model.reviewRecord)
        XCTAssertTrue(model.hasUnkeptRecording)
        let id = model.reviewRecord?.id
        store.failSave = false
        XCTAssertTrue(model.applyReview { _ in applied = true })
        XCTAssertTrue(applied)
        XCTAssertTrue(model.isReviewSaved)
        XCTAssertTrue(model.isApplied)
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.records.first?.id, id)
        XCTAssertFalse(model.applyReview { _ in XCTFail("Repeated Apply must be ignored") })
    }

    func testViewModelClockRefreshCapsAndPausesWithoutAffectingStoredSnapshots() {
        let clock = TestClock()
        let source = source(targets: [30])
        let model = viewModel(source: source, store: MemoryStopwatchStore(), clock: clock)
        model.start()
        clock.time = 100_000
        model.refreshTime()
        XCTAssertEqual(model.session?.phase, .paused)
        XCTAssertEqual(model.displaySeconds, 86_400)
        model.resume()
        XCTAssertEqual(model.session?.phase, .paused)
        model.finish(stepID: source.steps[0].id)
        XCTAssertEqual(model.reviewRecord?.source.steps[0].targetSeconds, 30)
    }

    func testHistoryLimitAndTrendsUseOnlyVisibleRecordings() {
        let source = source()
        let store = MemoryStopwatchStore()
        store.records = (0..<7).map { recording(source: source, durations: [Double(10 + $0)], date: epoch.addingTimeInterval(Double($0))) }
        let model = StopwatchViewModel(source: source, isProUnlocked: false, store: store, automaticallyRefresh: false)
        XCTAssertEqual(model.visibleRecords.count, HistoryAccessPolicy.freeRecordLimit)
        XCTAssertEqual(model.trendPoints.count, HistoryAccessPolicy.freeRecordLimit)
        XCTAssertTrue(model.hasOlderRecords)
        model.isProUnlocked = true
        XCTAssertEqual(model.visibleRecords.count, 7)
        XCTAssertEqual(model.trendPoints.count, 7)
        XCTAssertFalse(model.hasOlderRecords)
    }

    func testFreeHistoryLimitIsAppliedAcrossTemplatesBeforeFiltering() {
        let current = source()
        let other = StopwatchSource(templateID: UUID(), title: current.title, steps: current.steps)
        let store = MemoryStopwatchStore()
        store.records = [recording(source: current, durations: [10])]
            + (1...5).map { recording(source: other, durations: [Double($0)], date: epoch.addingTimeInterval(Double($0))) }
        let model = StopwatchViewModel(source: current, isProUnlocked: false, store: store, automaticallyRefresh: false)
        XCTAssertTrue(model.visibleRecords.isEmpty)
        XCTAssertTrue(model.hasOlderRecords)
        model.isProUnlocked = true
        XCTAssertEqual(model.visibleRecords.count, 1)
        XCTAssertEqual(model.trendPoints.count, 1, "Copied step IDs must remain isolated by template")
    }

    func testNameOnlyPlanCanReorderButCannotChangeDuringRecording() throws {
        let source = source(targets: [nil, nil, nil])
        let clock = TestClock()
        let model = StopwatchViewModel(source: source, isNewRoutine: true, isProUnlocked: false,
            store: MemoryStopwatchStore(), now: { clock.time }, date: { self.epoch }, automaticallyRefresh: false)
        model.moveSteps(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(model.source.steps.map(\.id), [source.steps[1].id, source.steps[2].id, source.steps[0].id])
        model.renameStep(id: source.steps[0].id, name: "Changed")
        model.start()
        model.renameStep(id: source.steps[0].id, name: "Too late")
        model.setTitle("Too late")
        XCTAssertEqual(model.session?.source.steps.last?.name, "Changed")
        XCTAssertEqual(model.source.title, source.title)
        model.finish(stepID: source.steps[1].id)
        XCTAssertFalse(model.canApply, "A partial name-only plan must not invent durations for unvisited steps")
        XCTAssertTrue(model.saveReview())
        model.backToPlan()
        XCTAssertNil(model.reviewRecord)
    }

    func testApplyErrorKeepsSavedRecordingAndDeleteErrorRemainsVisible() {
        let source = source(targets: [30])
        let store = MemoryStopwatchStore()
        let model = viewModel(source: source, store: store, clock: TestClock())
        model.start()
        model.finish(stepID: source.steps[0].id)
        XCTAssertFalse(model.applyReview { _ in throw StopwatchError.changedTemplate })
        XCTAssertTrue(model.isReviewSaved)
        XCTAssertFalse(model.isApplied)
        store.failDelete = true
        model.deleteReview()
        XCTAssertNotNil(model.reviewRecord)
        XCTAssertNotNil(model.errorMessage)
        store.failDelete = false
        model.deleteReview()
        XCTAssertNil(model.reviewRecord)
        XCTAssertTrue(store.records.isEmpty)
    }

    func testAllLocalRecordingsRecoverUnappliedPlanWithoutJoiningOtherTemplates() {
        let store = MemoryStopwatchStore()
        let current = source()
        let newPlan = source(targets: [nil, nil, nil])
        let savedOther = source()
        store.records = [recording(source: newPlan, durations: [10, 20, 30]),
                         recording(source: savedOther, durations: [11, 22, 33])]
        let library = StopwatchViewModel(source: current, isProUnlocked: true, isLibrary: true,
            savedTemplateIDs: [savedOther.templateID], store: store, automaticallyRefresh: false)
        XCTAssertEqual(library.visibleRecords.count, 2)
        library.show(store.records[0])
        XCTAssertTrue(library.appliesAsNewRoutine)
        XCTAssertTrue(library.canApply)
        library.backToPlan()
        library.show(store.records[1])
        XCTAssertTrue(library.needsSourceTemplate)
        XCTAssertFalse(library.canApply)
    }

    @MainActor
    func testEditorAppliesByIdentityMarksDirtyAndLeavesPersistedTemplateUntouched() throws {
        let directory = try temporaryDirectory()
        let library = TemplateLibraryStore(documentsDirectory: directory)
        let original = GameSequence(title: "Routine", rounds: [
            Round(name: "Prepare", durationSeconds: 30, orderIndex: 0),
            Round(name: "Focus", durationSeconds: 60, orderIndex: 1),
            Round(name: "Disabled", durationSeconds: 99, isActive: false, orderIndex: 2),
        ])
        let saved = try library.save(game: original)
        let editor = editor(library: library, directory: directory)
        XCTAssertTrue(editor.applySavedTemplate(saved).0)
        let source = editor.stopwatchSource()
        XCTAssertEqual(source.templateID, saved.id)
        XCTAssertEqual(source.steps.count, 2)
        let record = recording(source: source, durations: [7.6])
        editor.updateName(id: source.steps[0].id, name: "Renamed")
        editor.moveRounds(from: IndexSet(integer: 0), to: 2)
        try editor.applyStopwatchMeasurements(record)
        XCTAssertTrue(editor.hasUnsavedChanges)
        XCTAssertEqual(editor.rounds.first(where: { $0.id == source.steps[0].id })?.durationSeconds, 8)
        XCTAssertEqual(editor.rounds.first(where: { $0.id == source.steps[0].id })?.name, "Renamed")
        XCTAssertEqual(editor.rounds.first(where: { $0.id == source.steps[1].id })?.durationSeconds, 60)
        XCTAssertEqual(editor.rounds.first(where: { !$0.isActive })?.durationSeconds, 99)
        XCTAssertEqual(try library.loadDocument(id: saved.id).game.rounds, original.rounds)
        XCTAssertEqual(record.source.steps.first?.name, "Prepare")
        XCTAssertEqual(record.source.steps.first?.targetSeconds, 30)
        guard case .saved = editor.saveToDocuments(isProUnlocked: false) else { return XCTFail("Existing template must remain free to update") }
        XCTAssertFalse(editor.hasUnsavedChanges)
        XCTAssertEqual(try library.loadDocument(id: saved.id).game.rounds.first(where: { $0.id == source.steps[0].id })?.durationSeconds, 8)
    }

    @MainActor
    func testEditorRejectsDifferentTemplateReplacedOrDisabledStepsAtomically() throws {
        let directory = try temporaryDirectory()
        let library = TemplateLibraryStore(documentsDirectory: directory)
        let editor = editor(library: library, directory: directory)
        editor.applyStarterTemplate(StarterTemplateLibrary.defaultTemplate)
        let source = editor.stopwatchSource()
        let measured = recording(source: source, durations: [11, 22])
        editor.toggleActive(id: source.steps[1].id)
        let before = editor.rounds
        XCTAssertThrowsError(try editor.applyStopwatchMeasurements(measured))
        XCTAssertEqual(editor.rounds, before)
        editor.toggleActive(id: source.steps[1].id)
        editor.deleteRound(id: source.steps[1].id)
        editor.addRound()
        XCTAssertThrowsError(try editor.applyStopwatchMeasurements(measured))
        editor.applyStarterTemplate(StarterTemplateLibrary.templates[1])
        XCTAssertThrowsError(try editor.applyStopwatchMeasurements(measured))
    }

    @MainActor
    func testNewRoutineIdentitySurvivesDirtyDraftFirstSaveAndReloadWithProPolicy() throws {
        let directory = try temporaryDirectory()
        let library = TemplateLibraryStore(documentsDirectory: directory)
        let source = source(targets: [nil, nil, nil])
        let record = recording(source: source, durations: [11, 22, 33])
        let editor = editor(library: library, directory: directory)
        editor.applyStarterTemplate(StarterTemplateLibrary.defaultTemplate)
        try editor.applyNewStopwatchRoutine(record)
        XCTAssertNil(editor.currentSavedTemplateID)
        XCTAssertTrue(editor.hasUnsavedChanges)
        XCTAssertTrue(library.listTemplates().isEmpty)
        let restored = self.editor(library: library, directory: directory)
        restored.loadInitialTemplateIfNeeded()
        XCTAssertEqual(restored.stopwatchTemplateID, source.templateID)
        XCTAssertEqual(restored.rounds.map(\.id), source.steps.map(\.id))
        XCTAssertTrue(restored.hasUnsavedChanges)
        guard case .saved = restored.saveToDocuments(isProUnlocked: false) else { return XCTFail("First template must remain free") }
        XCTAssertFalse(restored.hasUnsavedChanges)
        XCTAssertEqual(restored.currentSavedTemplateID, source.templateID)
        let saved = try XCTUnwrap(library.listTemplates().first)
        let reloaded = self.editor(library: library, directory: try temporaryDirectory())
        XCTAssertTrue(reloaded.applySavedTemplate(saved).0)
        XCTAssertEqual(reloaded.stopwatchSource().steps.map(\.id), source.steps.map(\.id))
        XCTAssertEqual(reloaded.stopwatchSource().steps.map(\.targetSeconds), [11, 22, 33])
        XCTAssertThrowsError(try reloaded.applyNewStopwatchRoutine(record), "Recovery must not overwrite a saved source")
        try reloaded.applyNewStopwatchRoutine(recording(source: self.source(targets: [nil]), durations: [10]))
        guard case .requiresPro = reloaded.saveToDocuments(isProUnlocked: false) else { return XCTFail("A second saved template must retain the existing Pro gate") }
    }

    @MainActor
    func testApplyingEqualMeasurementsStillMarksEditorDirty() throws {
        let directory = try temporaryDirectory()
        let editor = editor(library: TemplateLibraryStore(documentsDirectory: directory), directory: directory)
        editor.applyStarterTemplate(StarterTemplateLibrary.defaultTemplate)
        let source = editor.stopwatchSource()
        XCTAssertFalse(editor.hasUnsavedChanges)
        try editor.applyStopwatchMeasurements(recording(source: source, durations: [Double(source.steps[0].targetSeconds!)]))
        XCTAssertTrue(editor.hasUnsavedChanges)
    }

    @MainActor
    private func editor(library: TemplateLibraryStore, directory: URL) -> GameEditorViewModel {
        let keys = ["lastTemplateID", "lastGameFileName", "hasMigratedLegacyTemplateLibrary"]
        let priorValues = keys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
        addTeardownBlock {
            for (key, value) in priorValues {
                if let value { UserDefaults.standard.set(value, forKey: key) }
                else { UserDefaults.standard.removeObject(forKey: key) }
            }
        }
        return GameEditorViewModel(templateLibrary: library,
            widgetSnapshotStore: WidgetSnapshotStore(containerURLProvider: { directory }),
            watchTemplateStore: WatchTemplateStore(containerURLProvider: { directory }),
            watchTemplatePublisher: { _ in }, draftDirectory: directory)
    }

    private func viewModel(source: StopwatchSource, store: MemoryStopwatchStore, clock: TestClock) -> StopwatchViewModel {
        StopwatchViewModel(source: source, isProUnlocked: true, store: store,
            now: { clock.time }, date: { self.epoch }, automaticallyRefresh: false)
    }
}

private final class TestClock { var time: TimeInterval = 0 }

@MainActor
private final class MemoryStopwatchStore: StopwatchRecordingStorage {
    var records: [StopwatchRecording] = []
    var failSave = false
    var failDelete = false

    func load(templateID: UUID?) throws -> StopwatchLoadResult {
        StopwatchLoadResult(records: records.filter { templateID == nil || $0.source.templateID == templateID }.sorted { $0.startedAt > $1.startedAt }, unreadableFiles: [])
    }
    func save(_ recording: StopwatchRecording) throws {
        if failSave { throw CocoaError(.fileWriteNoPermission) }
        records.removeAll { $0.id == recording.id }
        records.append(recording)
    }
    func delete(id: UUID) throws {
        if failDelete { throw CocoaError(.fileWriteNoPermission) }
        records.removeAll { $0.id == id }
    }
}

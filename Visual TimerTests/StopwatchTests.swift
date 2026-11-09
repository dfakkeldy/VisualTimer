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
        let loaded = try store.load()
        XCTAssertEqual(Set(loaded.records.map(\.id)), [record.id, unrelated.id])
        XCTAssertTrue(loaded.unreadableFiles.isEmpty)
        try store.delete(id: record.id)
        XCTAssertEqual(try store.load().records, [unrelated])
    }

    func testStoreRoundTripsWholeRecordsInDateAndFixedUUIDOrder() throws {
        let store = StopwatchRecordingStore(directory: try temporaryDirectory())
        let original = source()
        let changed = StopwatchSource(templateID: original.templateID, title: "Updated routine",
            steps: original.steps.map { .init(id: $0.id, name: $0.name, targetSeconds: 90) })
        let older = recording(source: original, durations: [32.125, 50.75, 10], date: epoch)
        let tiedDate = epoch.addingTimeInterval(60)
        func tied(_ id: String, source: StopwatchSource, durations: [Double]) -> StopwatchRecording {
            let record = recording(source: source, durations: durations, date: tiedDate)
            return StopwatchRecording(version: record.version, id: UUID(uuidString: id)!, source: source,
                startedAt: record.startedAt, finishedAt: record.finishedAt, measurements: record.measurements)
        }
        let tiedFirst = tied("00000000-0000-0000-0000-000000000001", source: changed, durations: [8.5, 9.25, 11])
        let tiedSecond = tied("00000000-0000-0000-0000-000000000002", source: original, durations: [15, 16, 17])
        let newest = recording(source: changed, durations: [21, 22, 23], date: epoch.addingTimeInterval(120))
        for record in [tiedSecond, older, newest, tiedFirst] { try store.save(record) }
        let loaded = try store.load()
        XCTAssertEqual(loaded.records, [newest, tiedFirst, tiedSecond, older])
        XCTAssertTrue(loaded.unreadableFiles.isEmpty)
    }

    func testMalformedFileReportedAndPreservedAlongsideReadableRecords() throws {
        let directory = try temporaryDirectory()
        let store = StopwatchRecordingStore(directory: directory)
        let record = recording(source: source(), durations: [12])
        try store.save(record)
        let malformed = directory.appendingPathComponent("broken.json")
        try Data("not a recording".utf8).write(to: malformed)
        let loaded = try store.load()
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
        XCTAssertThrowsError(try store.load())
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
        XCTAssertFalse(second.trendSteps.contains { $0.id == modifiedSteps[1].id },
                       "Matching names cannot join different step identities")
        XCTAssertEqual(second.trendSelection, source.steps[0].id)
        XCTAssertEqual(second.trendPoints.map(\.step.id), [source.steps[0].id])
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

    func testPartialNewPlanSkipsApplyPreflight() {
        let source = source(targets: [nil, nil])
        let store = MemoryStopwatchStore()
        let clock = TestClock()
        var preflightCount = 0
        let model = StopwatchViewModel(source: source, mode: .newPlan, isProUnlocked: false,
            applyPreflight: { _, _ in
                preflightCount += 1
                return .invalidRecording
            }, store: store, now: { clock.time }, date: { self.epoch }, automaticallyRefresh: false)
        model.start()
        clock.time = 12
        model.finish(stepID: source.steps[0].id)
        XCTAssertFalse(model.canApply)
        XCTAssertNil(model.applyBlocker)
        XCTAssertNil(model.applyBlockerMessage)
        XCTAssertFalse(model.applyReview { _ in XCTFail("Partial plans cannot apply") })
        XCTAssertEqual(preflightCount, 0)
        XCTAssertEqual(store.saveCount, 0)
        XCTAssertNil(model.errorMessage)
    }

    func testChangedTemplatePreflightBlocksBeforeSaveAndExplainsSaveFirst() {
        let source = source(targets: [30])
        let store = MemoryStopwatchStore()
        let clock = TestClock()
        let blocker = StopwatchError.changedTemplate(source.title)
        var preflightRecords: [StopwatchRecording] = []
        let model = StopwatchViewModel(source: source, isProUnlocked: false,
            applyPreflight: { record, kind in
                preflightRecords.append(record)
                XCTAssertEqual(kind, .existingTemplate)
                return blocker
            }, store: store, now: { clock.time }, date: { self.epoch }, automaticallyRefresh: false)
        model.start()
        clock.time = 12
        model.finish(stepID: source.steps[0].id)
        XCTAssertTrue(model.canApply)
        XCTAssertEqual(model.applyBlockerMessage, "Save this recording first. " + blocker.localizedDescription)
        XCTAssertFalse(model.applyReview { _ in XCTFail("A blocked review cannot apply") })
        XCTAssertEqual(model.errorMessage, blocker.localizedDescription)
        XCTAssertEqual(store.saveCount, 0)
        XCTAssertFalse(model.isReviewSaved)
        XCTAssertTrue(preflightRecords.allSatisfy { $0 == model.reviewRecord })
        XCTAssertFalse(preflightRecords.isEmpty)
        XCTAssertTrue(model.saveReview())
        XCTAssertEqual(model.applyBlockerMessage, blocker.localizedDescription)
        XCTAssertFalse(model.applyReview { _ in XCTFail("Saving does not clear the editor blocker") })
        XCTAssertEqual(store.saveCount, 1)
    }

    func testClearLiveApplyPreflightSavesAndAppliesCompleteNewPlan() {
        let source = source(targets: [nil])
        let store = MemoryStopwatchStore()
        let clock = TestClock()
        var blocker: StopwatchError? = .changedTemplate(source.title)
        var preflightCount = 0
        let model = StopwatchViewModel(source: source, mode: .newPlan, isProUnlocked: false,
            applyPreflight: { record, kind in
                preflightCount += 1
                XCTAssertEqual(record.source, source)
                XCTAssertEqual(kind, .newTemplate)
                return blocker
            }, store: store, now: { clock.time }, date: { self.epoch }, automaticallyRefresh: false)
        model.start()
        clock.time = 12
        model.finish(stepID: source.steps[0].id)
        XCTAssertNotNil(model.applyBlocker)
        blocker = nil
        var applied: StopwatchRecording?
        XCTAssertTrue(model.applyReview {
            XCTAssertEqual(store.records, [$0], "Apply must receive an already-saved recording")
            applied = $0
        })
        XCTAssertEqual(preflightCount, 2)
        XCTAssertEqual(store.saveCount, 1)
        XCTAssertNotNil(applied)
        XCTAssertEqual(applied, model.reviewRecord)
        XCTAssertTrue(model.isReviewSaved)
        XCTAssertTrue(model.isApplied)
        XCTAssertNil(model.errorMessage)
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
        let model = StopwatchViewModel(source: source, mode: .newPlan, isProUnlocked: false,
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
        XCTAssertFalse(model.applyReview { _ in throw StopwatchError.changedTemplate(source.title) })
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
        let library = StopwatchViewModel(source: current, mode: .library, isProUnlocked: true,
            savedTemplateTitles: [savedOther.templateID: savedOther.title], store: store, automaticallyRefresh: false)
        XCTAssertEqual(library.visibleRecords.count, 2)
        library.show(store.records[0])
        XCTAssertEqual(library.applyKind, .newTemplate)
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

    func testTrendDatesSnapshotsAndReviewPairingStayInOrder() {
        let original = source()
        let changed = StopwatchSource(templateID: original.templateID, title: original.title,
            steps: original.steps.map { .init(id: $0.id, name: $0.name, targetSeconds: 90) })
        let earlier = recording(source: original, durations: [32, 50, 10], date: epoch)
        let later = recording(source: changed, durations: [70, 80, 15], date: epoch.addingTimeInterval(86_400))
        let store = MemoryStopwatchStore()
        store.records = [later, earlier]
        let model = viewModel(source: changed, store: store, clock: TestClock())
        XCTAssertEqual(model.trendPoints.map(\.id), [earlier.id, later.id])
        XCTAssertEqual(model.trendPoints.map(\.date), [epoch, epoch.addingTimeInterval(86_400)])
        XCTAssertEqual(model.trendPoints.map(\.seconds), [32, 70])
        XCTAssertEqual(model.trendPoints.map { $0.step.targetSeconds }, [30, 90])
        model.show(earlier)
        XCTAssertEqual(model.reviewRows.map(\.label), ["1. Prepare", "2. Focus", "3. Rest"])
        XCTAssertEqual(model.reviewRows.map(\.step), original.steps)
        XCTAssertEqual(model.reviewRows.map(\.measurement), earlier.measurements)
        XCTAssertEqual(model.reviewRows.map(\.summary), [
            "Target 30s · Actual 32s · 2s over target",
            "Target 1m 0s · Actual 50s · 10s under target",
            "Target 15s · Actual 10s · 5s under target",
        ])
    }

    func testComparisonTextAndMinimumDurationHint() {
        let step = source(targets: [30]).steps[0]
        XCTAssertEqual(StopwatchText.comparison(step: step, actual: 32), "Target 30s · Actual 32s · 2s over target")
        XCTAssertEqual(StopwatchText.comparison(step: step, actual: 28), "Target 30s · Actual 28s · 2s under target")
        XCTAssertEqual(StopwatchText.comparison(step: step, actual: 28.5), "Target 30s · Actual 29s · 1s under target")
        XCTAssertEqual(StopwatchText.comparison(step: step, actual: 30.5), "Target 30s · Actual 31s · 1s over target")
        for actual in [29.5, 29.6, 30.4] {
            XCTAssertEqual(StopwatchText.comparison(step: step, actual: actual), "Target 30s · Actual 30s · matches target")
        }
        XCTAssertEqual(StopwatchText.comparison(step: source(targets: [nil]).steps[0], actual: 7), "Actual 7s · No target")
        let row = StopwatchViewModel.ComparisonRow(step: step, measurement: .init(stepID: step.id, seconds: 0.2), position: 1)
        XCTAssertEqual(row.appliedDurationHint, "Template duration: 5s")
        XCTAssertTrue(row.measurement.adjustsForTemplate)
        let rounded = StopwatchViewModel.ComparisonRow(step: step, measurement: .init(stepID: step.id, seconds: 7.6), position: 1)
        XCTAssertNil(rounded.appliedDurationHint)
        XCTAssertFalse(rounded.measurement.adjustsForTemplate)
    }

    func testShowAndBackToPlanCannotReplaceRunningOrUnsavedReview() {
        let source = source()
        let store = MemoryStopwatchStore()
        let saved = recording(source: source, durations: [10, 20, 30])
        store.records = [saved]
        let clock = TestClock()
        let model = viewModel(source: source, store: store, clock: clock)
        model.start()
        clock.time = 12
        model.refreshTime()
        model.show(saved)
        model.backToPlan()
        XCTAssertEqual(model.session?.phase, .running)
        XCTAssertEqual(model.session?.index, 0)
        XCTAssertEqual(model.displaySeconds, 12)
        XCTAssertNil(model.reviewRecord)
        XCTAssertEqual(model.source, source)
        XCTAssertEqual(store.saveCount, 0)
        model.finish(stepID: source.steps[0].id)
        let review = model.reviewRecord
        model.show(saved)
        model.backToPlan()
        XCTAssertEqual(model.reviewRecord, review)
        XCTAssertEqual(model.session?.phase, .review)
        XCTAssertFalse(model.isReviewSaved)
        XCTAssertEqual(store.records, [saved])
        XCTAssertEqual(store.saveCount, 0)
        model.discardUnkeptRecording()
        model.start()
        XCTAssertEqual(model.session?.phase, .running)
    }

    func testFailedReloadKeepsRecordsAndRetryRefreshesUnreadableCount() {
        let store = MemoryStopwatchStore()
        let source = source()
        let saved = recording(source: source, durations: [12])
        store.records = [saved]
        store.unreadableFiles = ["broken.json"]
        let model = viewModel(source: source, store: store, clock: TestClock())
        XCTAssertEqual(model.unreadableCount, 1)
        store.failLoad = true
        store.records = []
        store.unreadableFiles = []
        model.reload()
        XCTAssertEqual(model.records, [saved])
        XCTAssertEqual(model.unreadableCount, 1)
        XCTAssertTrue(model.hasLoadFailure)
        XCTAssertNotNil(model.errorMessage)
        store.failLoad = false
        model.reload()
        XCTAssertTrue(model.records.isEmpty)
        XCTAssertEqual(model.unreadableCount, 0)
        XCTAssertFalse(model.hasLoadFailure)
    }

    func testPlanBaselineProtectsEditsAndMovesOnlyAfterSuccessfulSave() {
        let baseline = source(targets: [nil])
        let store = MemoryStopwatchStore()
        let model = StopwatchViewModel(source: baseline, mode: .newPlan, isProUnlocked: false,
            store: store, automaticallyRefresh: false)
        XCTAssertFalse(model.hasUnkeptWork)
        model.setTitle("Changed plan")
        XCTAssertTrue(model.hasUnkeptPlan)
        model.setTitle(baseline.title)
        XCTAssertFalse(model.hasUnkeptPlan)
        model.renameStep(id: baseline.steps[0].id, name: "Changed step")
        model.backToPlan()
        XCTAssertTrue(model.hasUnkeptWork)
        model.start()
        XCTAssertFalse(model.hasUnkeptPlan)
        XCTAssertTrue(model.hasUnkeptRecording)
        model.finish(stepID: baseline.steps[0].id)
        store.failSave = true
        XCTAssertFalse(model.saveReview())
        model.discardUnkeptRecording()
        XCTAssertTrue(model.hasUnkeptPlan, "A failed save cannot advance the baseline")
        model.start()
        model.finish(stepID: baseline.steps[0].id)
        store.failSave = false
        XCTAssertTrue(model.saveReview())
        XCTAssertFalse(model.hasUnkeptWork)
        model.backToPlan()
        XCTAssertFalse(model.hasUnkeptPlan)
        model.setTitle("Another edit")
        XCTAssertTrue(model.hasUnkeptPlan)
        model.discardUnkeptWork()
        XCTAssertEqual(model.source.title, baseline.title)
        XCTAssertEqual(model.source.steps[0].name, "Changed step")
        XCTAssertFalse(model.hasUnkeptWork)
        model.show(store.records[0])
        XCTAssertEqual(model.reviewRecord, store.records.first)
    }

    func testDeletingOnlySavedNewPlanRetainsEditsAcrossDismissal() {
        let initial = source(targets: [nil])
        let store = MemoryStopwatchStore()
        let model = StopwatchViewModel(source: initial, mode: .newPlan, isProUnlocked: false,
            store: store, automaticallyRefresh: false)
        let workspace = StopwatchWorkspace()
        workspace.open(model)
        model.setTitle("Keep this plan")
        model.renameStep(id: initial.steps[0].id, name: "Keep this step")
        let edited = model.source
        model.start()
        model.finish(stepID: initial.steps[0].id)
        XCTAssertTrue(model.saveReview())
        XCTAssertFalse(model.hasUnkeptWork)
        store.failDelete = true
        XCTAssertFalse(model.deleteReview())
        XCTAssertNotNil(model.reviewRecord)
        store.failDelete = false
        model.errorMessage = nil
        store.failLoad = true
        XCTAssertTrue(model.deleteReview())
        store.failLoad = false
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(model.records.isEmpty)
        XCTAssertTrue(store.records.isEmpty)
        XCTAssertTrue(model.hasUnkeptPlan)
        XCTAssertEqual(model.source, edited)
        workspace.isPresented = false
        XCTAssertNil(workspace.sheetDidDismiss())
        XCTAssertTrue(workspace.model === model)
        workspace.returnToStopwatch()
        XCTAssertTrue(workspace.isPresented)
        model.discardUnkeptWork()
        XCTAssertEqual(model.source, initial)
    }

    func testDeleteUsesNewestRemainingSameRoutineBaselineEvenOutsideFreeHistory() {
        let initial = source(targets: [nil])
        let older = StopwatchSource(templateID: initial.templateID, title: "Older plan", steps: initial.steps)
        let newestRemaining = StopwatchSource(templateID: initial.templateID, title: "Newest kept plan", steps: initial.steps)
        let store = MemoryStopwatchStore()
        store.records = [recording(source: older, durations: [10], date: epoch),
                         recording(source: newestRemaining, durations: [12], date: epoch.addingTimeInterval(20))]
            + (30..<36).map { recording(source: source(targets: [nil]), durations: [15], date: epoch.addingTimeInterval(Double($0))) }
        let model = StopwatchViewModel(source: initial, mode: .newPlan, isProUnlocked: false,
            store: store, date: { self.epoch.addingTimeInterval(100) }, automaticallyRefresh: false)
        model.setTitle("Newest, now deleted")
        model.start()
        model.finish(stepID: initial.steps[0].id)
        XCTAssertTrue(model.saveReview())
        XCTAssertTrue(model.deleteReview())
        XCTAssertTrue(model.visibleRecords.isEmpty)
        XCTAssertTrue(model.hasOlderRecords)
        XCTAssertTrue(model.hasUnkeptPlan)
        model.discardUnkeptWork()
        XCTAssertEqual(model.source, newestRemaining, "Baseline comes from all retained records, newest first")
    }

    func testDiscardMeasurementsKeepsEditedPlanAndAllowsAnotherRecording() {
        let initial = source(targets: [nil])
        let store = MemoryStopwatchStore()
        let model = StopwatchViewModel(source: initial, mode: .newPlan, isProUnlocked: false,
            store: store, automaticallyRefresh: false)
        XCTAssertFalse(model.canDiscardRecordingKeepingPlan)
        model.setTitle("Keep routine")
        model.renameStep(id: initial.steps[0].id, name: "Keep step")
        let edited = model.source
        model.start()
        XCTAssertTrue(model.canDiscardRecordingKeepingPlan)
        XCTAssertEqual(model.discardAction, "Discard recording and plan")
        model.finish(stepID: initial.steps[0].id)
        XCTAssertTrue(model.canDiscardRecordingKeepingPlan)
        model.discardUnkeptRecording()
        XCTAssertEqual(model.source, edited)
        XCTAssertTrue(model.hasUnkeptPlan)
        XCTAssertFalse(model.canDiscardRecordingKeepingPlan)
        XCTAssertTrue(model.canStart)
        model.start()
        XCTAssertEqual(model.session?.source, edited)
        XCTAssertEqual(model.session?.phase, .running)
        XCTAssertEqual(store.saveCount, 0)
    }

    func testWorkspaceEntitlementUpdatesWithoutPaywallRefreshBothHistoryDirections() {
        let original = source(targets: [nil])
        let store = MemoryStopwatchStore()
        store.records = (0..<7).map {
            recording(source: original, durations: [Double($0 + 10)], date: epoch.addingTimeInterval(Double($0)))
        }
        let model = StopwatchViewModel(source: original, mode: .newPlan, isProUnlocked: false,
            store: store, automaticallyRefresh: false)
        let workspace = StopwatchWorkspace()
        workspace.open(model)
        model.setTitle("Retained unsaved plan")
        workspace.isPresented = false
        XCTAssertNil(workspace.sheetDidDismiss())
        XCTAssertEqual(model.visibleRecords.count, 5)
        XCTAssertTrue(model.hasOlderRecords)
        workspace.updateProAccess(true)
        XCTAssertEqual(model.visibleRecords.count, 7)
        XCTAssertFalse(model.hasOlderRecords)
        workspace.updateProAccess(false)
        XCTAssertEqual(model.visibleRecords.count, 5)
        XCTAssertTrue(model.hasOlderRecords)
        XCTAssertTrue(workspace.model === model)
        XCTAssertFalse(workspace.isPresented)
        XCTAssertEqual(model.source.title, "Retained unsaved plan")
    }

    func testPlanShowGuardAndDiscardDialogNameTheWorkAtRisk() {
        let source = source(targets: [nil])
        let store = MemoryStopwatchStore()
        let saved = recording(source: source, durations: [12])
        store.records = [saved]
        let model = StopwatchViewModel(source: source, mode: .newPlan, isProUnlocked: true,
            store: store, automaticallyRefresh: false)
        model.setTitle("Unsaved edits")
        model.show(saved)
        XCTAssertNil(model.reviewRecord)
        XCTAssertEqual(model.workspaceStatus, "Unsaved plan")
        XCTAssertEqual(model.discardTitle, "Discard this plan?")
        XCTAssertEqual(model.discardHint, Theme.Stopwatch.discardPlanHint)
        model.start()
        XCTAssertEqual(model.discardTitle, "Discard this recording?")
        XCTAssertEqual(model.discardHint, Theme.Stopwatch.discardPlanAndRecordingHint)
        model.finish(stepID: source.steps[0].id)
        XCTAssertEqual(model.workspaceStatus, "Unsaved review")
        XCTAssertEqual(model.discardTitle, "Discard these measurements?")
        XCTAssertEqual(model.discardHint, Theme.Stopwatch.discardPlanAndRecordingHint)
        XCTAssertEqual(store.saveCount, 0)
    }

    func testSafeDismissRetainsSameWorkspaceAndBlocksReplacementUntilDiscard() {
        for mode: StopwatchViewModel.Mode in [.template, .newPlan] {
            let store = MemoryStopwatchStore()
            let model = StopwatchViewModel(source: source(), mode: mode, isProUnlocked: false,
                store: store, automaticallyRefresh: false)
            let workspace = StopwatchWorkspace()
            workspace.open(model)
            if mode == .newPlan { model.setTitle("Edited plan") } else { model.start() }
            workspace.isPresented = false // SwiftUI swipe dismissal
            XCTAssertNil(workspace.sheetDidDismiss())
            XCTAssertTrue(workspace.model === model)
            XCTAssertTrue(workspace.hasUnkeptWork)
            let replacement = viewModel(source: source(), store: store, clock: TestClock())
            workspace.open(replacement)
            XCTAssertTrue(workspace.model === model)
            XCTAssertFalse(workspace.isPresented)
            workspace.returnToStopwatch()
            XCTAssertTrue(workspace.isPresented)
            if mode == .template {
                model.finish(stepID: model.source.steps[0].id)
                workspace.isPresented = false
                XCTAssertNil(workspace.sheetDidDismiss())
                XCTAssertTrue(workspace.model === model, "An unsaved review survives a swipe too")
            }
            model.discardUnkeptWork()
            workspace.isPresented = false
            XCTAssertNil(workspace.sheetDidDismiss())
            XCTAssertNil(workspace.model)
            workspace.open(replacement)
            XCTAssertTrue(workspace.model === replacement)
            XCTAssertEqual(store.saveCount, 0)
        }
    }

    func testPaywallDismissalReopensSameModelAndRefreshesProWithAndWithoutUnkeptWork() {
        for mode: StopwatchViewModel.Mode in [.library, .newPlan] {
            let model = StopwatchViewModel(source: source(), mode: mode, isProUnlocked: false,
                store: MemoryStopwatchStore(), automaticallyRefresh: false)
            let workspace = StopwatchWorkspace()
            workspace.open(model)
            if mode == .newPlan { model.setTitle("Retained plan") }
            let retainedSource = model.source
            workspace.requestPro(.fullHistory)
            XCTAssertFalse(workspace.isPresented)
            workspace.returnToStopwatch()
            XCTAssertFalse(workspace.isPresented, "Wait for the paywall to close")
            workspace.open(viewModel(source: source(), store: MemoryStopwatchStore(), clock: TestClock()))
            XCTAssertTrue(workspace.model === model)
            XCTAssertEqual(workspace.sheetDidDismiss(), .fullHistory)
            workspace.paywallDidDismiss(isProUnlocked: true)
            XCTAssertTrue(workspace.isPresented)
            XCTAssertTrue(workspace.model === model)
            XCTAssertTrue(model.isProUnlocked)
            XCTAssertEqual(model.source, retainedSource)
            workspace.requestPro(.fullHistory)
            XCTAssertEqual(workspace.sheetDidDismiss(), .fullHistory)
            workspace.paywallDidDismiss(isProUnlocked: false)
            XCTAssertTrue(workspace.model === model)
            XCTAssertFalse(model.isProUnlocked)
        }
    }

    func testEditorPaywallRefreshesProForRetainedWorkspaceWithoutReopeningIt() {
        let model = StopwatchViewModel(source: source(), mode: .newPlan, isProUnlocked: false,
            store: MemoryStopwatchStore(), automaticallyRefresh: false)
        let workspace = StopwatchWorkspace()
        workspace.open(model)
        model.setTitle("Unsaved routine")
        workspace.isPresented = false
        XCTAssertNil(workspace.sheetDidDismiss())
        workspace.paywallDidDismiss(isProUnlocked: true)
        XCTAssertTrue(workspace.model === model)
        XCTAssertTrue(model.isProUnlocked)
        XCTAssertFalse(workspace.isPresented)
        workspace.returnToStopwatch()
        XCTAssertTrue(workspace.isPresented)
    }

    func testFinishEarlyCountsOnlyStepsAfterCurrentAndExplainsPartialPlan() {
        let source = source(targets: [nil, nil, nil])
        let clock = TestClock()
        let model = StopwatchViewModel(source: source, mode: .newPlan, isProUnlocked: false,
            store: MemoryStopwatchStore(), now: { clock.time }, automaticallyRefresh: false)
        XCTAssertEqual(model.unmeasuredStepCount, 0)
        model.start()
        XCTAssertEqual(model.unmeasuredStepCount, 2)
        XCTAssertEqual(model.finishEarlyHint, "“Prepare” keeps its time so far. 2 later steps won't be measured. " + Theme.Stopwatch.partialNewHint)
        model.pause()
        XCTAssertEqual(model.unmeasuredStepCount, 2)
        model.next(stepID: source.steps[0].id)
        XCTAssertEqual(model.unmeasuredStepCount, 1)
        XCTAssertEqual(model.finishEarlyHint, "“Focus” keeps its time so far. 1 later step won't be measured. " + Theme.Stopwatch.partialNewHint)
        model.finish(stepID: source.steps[1].id)
        XCTAssertEqual(model.reviewRecord?.measurements.count, 2)
        XCTAssertEqual(model.unmeasuredStepCount, 0)
        XCTAssertFalse(model.canApply)
        XCTAssertTrue(model.saveReview())
        model.backToPlan()
        model.start()
        clock.time = 1
        model.next(stepID: source.steps[0].id)
        clock.time = 2
        model.next(stepID: source.steps[1].id)
        XCTAssertEqual(model.unmeasuredStepCount, 0)
    }

    func testStepOptionsOffsetsMoveAndDeleteByIdentity() {
        let source = source(targets: [nil, nil, nil])
        let model = StopwatchViewModel(source: source, mode: .newPlan, isProUnlocked: false,
            store: MemoryStopwatchStore(), automaticallyRefresh: false)
        // Same single-row offsets used by Menu and accessibility actions.
        model.moveSteps(from: IndexSet(integer: 1), to: 0)
        XCTAssertEqual(model.source.steps.map(\.id), [source.steps[1].id, source.steps[0].id, source.steps[2].id])
        model.moveSteps(from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(model.source.steps, source.steps)
        model.selectedTrendStepID = source.steps[1].id
        model.removeSteps(at: IndexSet(integer: 1))
        XCTAssertEqual(model.source.steps.map(\.id), [source.steps[0].id, source.steps[2].id])
        XCTAssertEqual(model.selectedTrendStepID, source.steps[0].id)
        XCTAssertTrue(model.hasUnkeptPlan)
    }

    func testAnnouncementInputsChangeAtTransitionsWhileTicksOnlyRefreshElapsedTime() {
        let clock = TestClock()
        let source = source()
        let model = viewModel(source: source, store: MemoryStopwatchStore(), clock: clock)
        XCTAssertNil(model.currentStepAnnouncement)
        model.start()
        XCTAssertEqual(model.currentStepAnnouncement, "Step 1 of 3, Prepare")
        XCTAssertEqual(model.workspaceStatus, "Step 1 of 3 · Recording")
        clock.time = 1
        model.refreshTime()
        clock.time = 2
        model.refreshTime()
        XCTAssertEqual(model.currentStepAnnouncement, "Step 1 of 3, Prepare")
        XCTAssertFalse(model.hasReachedStepLimit)
        model.next(stepID: source.steps[0].id)
        XCTAssertEqual(model.currentStepAnnouncement, "Step 2 of 3, Focus")
        model.pause()
        XCTAssertEqual(model.session?.phase, .paused)
        XCTAssertEqual(model.workspaceStatus, "Step 2 of 3 · Paused")
        model.resume()
        XCTAssertEqual(model.session?.phase, .running)
        clock.time = 100_000
        model.refreshTime()
        XCTAssertTrue(model.hasReachedStepLimit)
        XCTAssertEqual(model.session?.phase, .paused)
        model.finish(stepID: source.steps[1].id)
        XCTAssertNil(model.currentStepAnnouncement)
    }

    func testStartBlockerNamesFirstProblemInEveryMode() {
        for mode: StopwatchViewModel.Mode in [.template, .newPlan, .library] {
            let id = UUID()
            let invalid = StopwatchSource(templateID: id, title: " \n", steps: [
                .init(id: UUID(), name: "Prepare", targetSeconds: nil),
                .init(id: UUID(), name: " ", targetSeconds: nil),
            ])
            let model = StopwatchViewModel(source: invalid, mode: mode, isProUnlocked: false,
                store: MemoryStopwatchStore(), automaticallyRefresh: false)
            XCTAssertEqual(model.startBlocker, mode == .template
                ? "Add a routine name. Change it in the template editor." : "Add a routine name")
            XCTAssertFalse(model.canStart)
            let named = StopwatchSource(templateID: id, title: "Routine", steps: invalid.steps)
            let namedModel = StopwatchViewModel(source: named, mode: mode, isProUnlocked: false,
                store: MemoryStopwatchStore(), automaticallyRefresh: false)
            XCTAssertEqual(namedModel.startBlocker, mode == .template
                ? "Step 2 needs a name. Change it in the template editor." : "Step 2 needs a name")
            XCTAssertFalse(namedModel.canStart)
            let empty = StopwatchViewModel(source: .init(templateID: id, title: "Routine", steps: []),
                mode: mode, isProUnlocked: false, store: MemoryStopwatchStore(), automaticallyRefresh: false)
            XCTAssertEqual(empty.startBlocker, mode == .template
                ? "Add at least one step. Change it in the template editor." : "Add at least one step")
        }
        let model = viewModel(source: source(), store: MemoryStopwatchStore(), clock: TestClock())
        XCTAssertNil(model.startBlocker)
        XCTAssertTrue(model.canStart)
        model.start()
        XCTAssertFalse(model.canStart)
    }

    func testEarlierStepLabelsAndCurrentSavedTemplateName() {
        let current = source()
        let replaced = StopwatchSource.Step(id: UUID(), name: "Focus", targetSeconds: 12)
        let oldSource = StopwatchSource(templateID: current.templateID, title: "Old routine", steps: [replaced])
        let store = MemoryStopwatchStore()
        store.records = [recording(source: oldSource, durations: [15])]
        let model = viewModel(source: current, store: store, clock: TestClock())
        XCTAssertEqual(model.trendStepLabel(current.steps[1]), "Focus")
        XCTAssertEqual(model.trendStepLabel(replaced), "Focus (not in current plan)")
        model.selectedTrendStepID = replaced.id
        XCTAssertEqual(model.trendPoints.map(\.seconds), [15])
        let other = source()
        let library = StopwatchViewModel(source: other, mode: .library, isProUnlocked: true,
            savedTemplateTitles: [current.templateID: "Renamed routine"], store: store, automaticallyRefresh: false)
        library.show(store.records[0])
        XCTAssertTrue(library.needsSourceTemplate)
        XCTAssertEqual(library.openSourceHint, "Open “Renamed routine” in Templates to apply this recording's measurements.")
        let fallback = StopwatchViewModel(source: other, mode: .library, isProUnlocked: true,
            store: store, automaticallyRefresh: false)
        fallback.show(store.records[0])
        XCTAssertEqual(fallback.openSourceHint, "Open “Old routine” in Templates to apply this recording's measurements.")
    }

    func testTrendOmitsUnmeasuredNewStepAndFallsBackToMeasuredSelection() {
        let source = source(targets: [nil, nil])
        let store = MemoryStopwatchStore()
        let clock = TestClock()
        let model = StopwatchViewModel(source: source, mode: .newPlan, isProUnlocked: false,
            store: store, now: { clock.time }, date: { self.epoch }, automaticallyRefresh: false)
        model.start()
        clock.time = 10
        model.next(stepID: source.steps[0].id)
        clock.time = 20
        model.finish(stepID: source.steps[1].id)
        XCTAssertTrue(model.saveReview())
        model.backToPlan()
        model.addStep()
        XCTAssertEqual(model.source.steps.last?.name, "")
        XCTAssertEqual(model.trendSteps, source.steps)
        model.selectedTrendStepID = model.source.steps.last?.id
        XCTAssertEqual(model.trendSelection, source.steps[0].id)
        XCTAssertEqual(model.trendPoints.map(\.seconds), [10])
        model.selectedTrendStepID = source.steps[1].id
        XCTAssertEqual(model.trendSelection, source.steps[1].id)
        XCTAssertEqual(model.trendPoints.map(\.step.id), [source.steps[1].id])
    }

    func testCleanStarterDraftRestoresTemplateAndStepIdentities() throws {
        let directory = try temporaryDirectory()
        let library = TemplateLibraryStore(documentsDirectory: directory)
        let original = editor(library: library, directory: directory)
        original.applyStarterTemplate(StarterTemplateLibrary.defaultTemplate)
        let source = original.stopwatchSource()
        XCTAssertFalse(original.hasUnsavedChanges)
        let restored = editor(library: library, directory: directory)
        restored.loadInitialTemplateIfNeeded()
        XCTAssertNil(restored.currentSavedTemplateID)
        XCTAssertEqual(restored.stopwatchTemplateID, source.templateID)
        XCTAssertEqual(restored.stopwatchSource().steps, source.steps)
        XCTAssertFalse(restored.hasUnsavedChanges)
        let draft = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("TemplateDraft.json"))) as? [String: Any]
        XCTAssertEqual(draft?["stopwatchTemplateID"] as? String, source.templateID.uuidString)
    }

    func testFirstAutoSaveKeepsIdentityAndAppliedDurations() throws {
        let directory = try temporaryDirectory()
        let library = TemplateLibraryStore(documentsDirectory: directory)
        let editor = editor(library: library, directory: directory)
        editor.applyStarterTemplate(StarterTemplateLibrary.defaultTemplate)
        let source = editor.stopwatchSource()
        let durations = source.steps.enumerated().map { 7.6 + Double($0.offset) }
        try editor.applyStopwatchRecording(recording(source: source, durations: durations), kind: .existingTemplate)
        editor.autoSave()
        XCTAssertEqual(editor.currentSavedTemplateID, source.templateID)
        XCTAssertEqual(editor.stopwatchTemplateID, source.templateID)
        XCTAssertFalse(editor.hasUnsavedChanges)
        let document = try library.loadDocument(id: source.templateID)
        XCTAssertEqual(document.game.activeRounds.map(\.id), source.steps.map(\.id))
        XCTAssertEqual(document.game.activeRounds.map(\.durationSeconds), durations.map { Int($0.rounded()) })
    }

    func testApplyKindAndEditorDispatchForNewPlan() throws {
        let directory = try temporaryDirectory()
        let library = TemplateLibraryStore(documentsDirectory: directory)
        let editor = editor(library: library, directory: directory)
        editor.applyStarterTemplate(StarterTemplateLibrary.defaultTemplate)
        let source = source(targets: [nil])
        let model = StopwatchViewModel(source: source, mode: .newPlan, isProUnlocked: false,
            store: MemoryStopwatchStore(), automaticallyRefresh: false)
        XCTAssertEqual(model.applyKind, .newTemplate)
        try editor.applyStopwatchRecording(recording(source: source, durations: [12]), kind: model.applyKind)
        XCTAssertEqual(editor.stopwatchSource().steps.map(\.targetSeconds), [12])
        XCTAssertEqual(editor.stopwatchTemplateID, source.templateID)
        XCTAssertTrue(editor.hasUnsavedChanges)
    }

    func testEditorApplyPreflightMatchesBothApplicationPathsAndNamesRecovery() throws {
        let directory = try temporaryDirectory()
        let library = TemplateLibraryStore(documentsDirectory: directory)
        let editor = editor(library: library, directory: directory)
        editor.applyStarterTemplate(StarterTemplateLibrary.defaultTemplate)
        let original = editor.stopwatchSource()
        let measured = recording(source: original, durations: [12, 13])
        XCTAssertNil(editor.stopwatchApplyBlocker(measured, kind: .existingTemplate))
        editor.toggleActive(id: original.steps[1].id)
        let before = editor.rounds
        let blocker = try XCTUnwrap(editor.stopwatchApplyBlocker(measured, kind: .existingTemplate))
        XCTAssertEqual(blocker.localizedDescription, "The template or its enabled steps have changed. Open “Game Night”, then Local stopwatch recordings to apply. Restore any removed or disabled measured steps first.")
        XCTAssertThrowsError(try editor.applyStopwatchRecording(measured, kind: .existingTemplate)) {
            XCTAssertEqual($0.localizedDescription, blocker.localizedDescription)
        }
        XCTAssertEqual(editor.rounds, before)
        editor.toggleActive(id: original.steps[1].id)
        editor.applyStarterTemplate(StarterTemplateLibrary.templates[1])
        XCTAssertNotNil(editor.stopwatchApplyBlocker(measured, kind: .existingTemplate))
        let plan = source(targets: [nil, nil])
        let partial = recording(source: plan, durations: [10])
        XCTAssertEqual(editor.stopwatchApplyBlocker(partial, kind: .newTemplate)?.localizedDescription,
                       Theme.Stopwatch.invalidRecording)
        let complete = recording(source: plan, durations: [10, 20])
        XCTAssertNil(editor.stopwatchApplyBlocker(complete, kind: .newTemplate))
        try editor.applyStopwatchRecording(complete, kind: .newTemplate)
        guard case .saved = editor.saveToDocuments(isProUnlocked: false) else { return XCTFail("First save remains free") }
        editor.gameTitle = "Current saved title"
        guard case .saved = editor.saveToDocuments(isProUnlocked: false) else { return XCTFail("Updating remains free") }
        let savedBlocker = try XCTUnwrap(editor.stopwatchApplyBlocker(complete, kind: .newTemplate))
        XCTAssertTrue(savedBlocker.localizedDescription.contains("Open “Current saved title”, then Local stopwatch recordings to apply."))
        XCTAssertThrowsError(try editor.applyNewStopwatchRoutine(complete)) {
            XCTAssertEqual($0.localizedDescription, savedBlocker.localizedDescription)
        }
        XCTAssertEqual(editor.gameTitle, "Current saved title")
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
    var failLoad = false
    var unreadableFiles: [String] = []
    var saveCount = 0

    func load() throws -> StopwatchLoadResult {
        if failLoad { throw CocoaError(.fileReadNoPermission) }
        return StopwatchLoadResult(records: records.sorted { $0.startedAt > $1.startedAt }, unreadableFiles: unreadableFiles)
    }
    func save(_ recording: StopwatchRecording) throws {
        if failSave { throw CocoaError(.fileWriteNoPermission) }
        saveCount += 1
        records.removeAll { $0.id == recording.id }
        records.append(recording)
    }
    func delete(id: UUID) throws {
        if failDelete { throw CocoaError(.fileWriteNoPermission) }
        records.removeAll { $0.id == id }
    }
}

import SwiftUI
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

final class GameEditorViewModel: ObservableObject {

    @Published var gameTitle: String = "New Game"
    @Published var rounds: [Round] = []
    @Published var roundCount: Int = 1
    /// Shared by local stopwatch recordings and the eventual saved template.
    @Published private var unsavedTemplateID = UUID()
    var stopwatchTemplateID: UUID { currentSavedTemplateID ?? unsavedTemplateID }
    @Published var expandedRoundId: UUID?
    @Published private(set) var savedTemplates: [SavedTemplate] = []
    /// Round colours of each saved template, for the picker cards.
    @Published private(set) var savedTemplateSegments: [UUID: [SequenceSegment]] = [:]
    /// The starter template on screen, if the sequence came from one.
    @Published private(set) var currentStarterID: String?
    /// The sequence as last loaded or saved, to tell whether there are edits to keep.
    @Published private var cleanState: EditorSnapshot?
    @Published private var hasPendingStopwatchApplication = false

    struct EditorSnapshot: Equatable, Codable {
        let title: String
        let rounds: [Round]
        let roundCount: Int
    }

    private var currentSnapshot: EditorSnapshot {
        EditorSnapshot(title: gameTitle, rounds: rounds, roundCount: roundCount)
    }

    /// True when the sequence on screen differs from what was loaded or saved.
    var hasUnsavedChanges: Bool { hasPendingStopwatchApplication || cleanState != currentSnapshot }

    /// True when the sequence on screen is one of the saved templates.
    var isShowingSavedTemplate: Bool {
        guard currentStarterID == nil, let id = currentSavedTemplateID else { return false }
        return savedTemplates.contains { $0.id == id }
    }

    private func markClean() {
        hasPendingStopwatchApplication = false
        cleanState = currentSnapshot
        persistDraft()
    }

    // MARK: - Draft (edits that survive an app close)

    private struct EditorDraft: Codable {
        let current: EditorSnapshot
        let clean: EditorSnapshot?
        let starterID: String?
        let stopwatchTemplateID: UUID?
        let savedTemplateID: UUID?
        let pendingStopwatchApplication: Bool?
    }

    private let draftURL: URL
    private var draftCancellable: AnyCancellable?

    /// Keeps unsaved edits and identities for sources not yet saved as templates.
    /// A clean saved template can be loaded from its document instead.
    func persistDraft() {
        // Keep clean unsaved sources too: their step/template identities must
        // survive relaunch before their first template save.
        guard !rounds.isEmpty, hasUnsavedChanges || currentSavedTemplateID == nil else {
            try? FileManager.default.removeItem(at: draftURL)
            return
        }
        let draft = EditorDraft(current: currentSnapshot, clean: cleanState, starterID: currentStarterID,
            stopwatchTemplateID: stopwatchTemplateID, savedTemplateID: currentSavedTemplateID,
            pendingStopwatchApplication: hasPendingStopwatchApplication)
        guard let data = try? JSONEncoder().encode(draft) else { return }
        try? data.write(to: draftURL, options: .atomic)
    }

    /// Puts back unsaved edits from before the app closed. Malformed drafts are discarded.
    private func restoreDraft() -> Bool {
        guard let data = try? Data(contentsOf: draftURL) else { return false }
        guard let draft = try? JSONDecoder().decode(EditorDraft.self, from: data) else {
            try? FileManager.default.removeItem(at: draftURL)
            return false
        }
        gameTitle = draft.current.title
        rounds = draft.current.rounds
        roundCount = draft.current.roundCount
        currentStarterID = draft.starterID
        unsavedTemplateID = draft.stopwatchTemplateID ?? currentSavedTemplateID ?? UUID()
        if draft.stopwatchTemplateID != nil {
            lastTemplateID = draft.savedTemplateID?.uuidString ?? ""
        }
        cleanState = draft.clean
        hasPendingStopwatchApplication = draft.pendingStopwatchApplication ?? false
        return true
    }

    @AppStorage("lastGameFileName") private var lastGameFileName: String = ""
    @AppStorage("lastTemplateID") private var lastTemplateID: String = ""
    @AppStorage("hasMigratedLegacyTemplateLibrary") private var hasMigratedLegacyTemplateLibrary: Bool = false

    private let parser = GameFileParser()
    private let templateLibrary: TemplateLibraryStore
    private let widgetSnapshotStore: WidgetSnapshotStore
    private let watchTemplateStore: WatchTemplateStore
    private let watchTemplatePublisher: @MainActor ([WatchTemplate]) -> Void
    private var isWidgetPublishingEnabled = false

    enum TemplateSaveResult {
        case saved
        case requiresPro
        case failed([ParseError])
    }

    enum TemplateImportResult {
        case imported(SavedTemplate)
        case requiresPro
        case failed([ParseError])
    }

    init(
        templateLibrary: TemplateLibraryStore = TemplateLibraryStore(),
        widgetSnapshotStore: WidgetSnapshotStore = WidgetSnapshotStore(),
        watchTemplateStore: WatchTemplateStore = WatchTemplateStore(),
        watchTemplatePublisher: @escaping @MainActor ([WatchTemplate]) -> Void = {
            WatchTemplateConnectivity.shared.publish(templates: $0)
        },
        draftDirectory: URL? = nil
    ) {
        let base = draftDirectory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.draftURL = base.appendingPathComponent("TemplateDraft.json")
        self.templateLibrary = templateLibrary
        self.widgetSnapshotStore = widgetSnapshotStore
        self.watchTemplateStore = watchTemplateStore
        self.watchTemplatePublisher = watchTemplatePublisher
        draftCancellable = Publishers.CombineLatest3($gameTitle, $rounds, $roundCount)
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.persistDraft() }
    }

    var isExpanded: Bool { expandedRoundId != nil }

    var currentSavedTemplateID: UUID? {
        UUID(uuidString: lastTemplateID)
    }

    var canSaveOrStartTemplate: Bool {
        rounds.contains { $0.isActive }
    }

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
        objectWillChange.send()
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
    //
    // These mutate array elements in-place without triggering @Published.
    // PlayerEditView tracks changes locally via @State, so it stays open
    // while editing. When the user taps Done, expandedRoundId = nil triggers
    // the re-render that updates the collapsed PlayerRowView.

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

    func updateCountsAsPlayer(id: UUID, countsAsPlayer: Bool) {
        guard let index = rounds.firstIndex(where: { $0.id == id }) else { return }
        rounds[index].countsAsPlayer = countsAsPlayer
    }

    // MARK: - Starter Templates

    func applyStarterTemplate(_ template: StarterTemplate) {
        var game = template.game
        game.normalizeTemplateFields()
        gameTitle = game.title
        rounds = game.rounds
        roundCount = game.roundCount
        expandedRoundId = nil
        lastTemplateID = ""
        unsavedTemplateID = UUID()
        currentStarterID = template.id
        markClean()
    }

    func applySavedTemplate(_ template: SavedTemplate) -> (Bool, [ParseError]) {
        do {
            let document = try templateLibrary.loadDocument(id: template.id)
            applyDocument(document)
            lastTemplateID = template.id.uuidString
            currentStarterID = nil
            markClean()
            return (true, [])
        } catch {
            return (false, [ParseError("Failed to load template: \(error.localizedDescription)")])
        }
    }

    func loadInitialTemplateIfNeeded() {
        refreshSavedTemplates()
        migrateLegacyTemplateIfNeeded()
        guard rounds.isEmpty else { return }
        if restoreDraft() { return }
        if loadLastGame() { return }
        applyStarterTemplate(StarterTemplateLibrary.defaultTemplate)
    }

    // MARK: - Build Sequence

    func buildGameSequence() -> GameSequence {
        var game = GameSequence(title: gameTitle, rounds: rounds, roundCount: roundCount)
        game.normalizeTemplateFields()
        return game
    }

    // MARK: - Stopwatch recording integration

    func stopwatchSource() -> StopwatchSource {
        StopwatchSource(templateID: stopwatchTemplateID, title: gameTitle,
            steps: buildGameSequence().activeRounds.map {
                StopwatchSource.Step(id: $0.id, name: $0.name, targetSeconds: $0.durationSeconds)
            })
    }

    func applyStopwatchRecording(_ recording: StopwatchRecording, kind: StopwatchViewModel.ApplyKind) throws {
        switch kind {
        case .existingTemplate: try applyStopwatchMeasurements(recording)
        case .newTemplate: try applyNewStopwatchRoutine(recording)
        }
    }

    /// Shared preflight for the review UI and both application paths.
    func stopwatchApplyBlocker(_ recording: StopwatchRecording, kind: StopwatchViewModel.ApplyKind) -> StopwatchError? {
        do { try recording.validate() }
        catch { return (error as? StopwatchError) ?? .invalidRecording }
        switch kind {
        case .existingTemplate:
            let activeIDs = Set(rounds.filter(\.isActive).map(\.id))
            guard recording.source.templateID == stopwatchTemplateID,
                  Set(rounds.map(\.id)).count == rounds.count,
                  recording.measurements.allSatisfy({ activeIDs.contains($0.stepID) }) else {
                let savedTitle = savedTemplateTitle(recording.source.templateID)
                return .changedTemplate(savedTitle ?? recording.source.title)
            }
        case .newTemplate:
            guard recording.isComplete else { return .invalidRecording }
            if let savedTitle = savedTemplateTitle(recording.source.templateID) {
                return .changedTemplate(savedTitle)
            }
        }
        return nil
    }

    private func savedTemplateTitle(_ id: UUID) -> String? {
        (try? templateLibrary.loadDocument(id: id))
            .flatMap { $0.templateID == id ? $0.title : nil }
    }

    /// Applies only to the same template and enabled step identities. No save,
    /// CloudKit publication, or clean-state update occurs here.
    func applyStopwatchMeasurements(_ recording: StopwatchRecording) throws {
        if let blocker = stopwatchApplyBlocker(recording, kind: .existingTemplate) { throw blocker }
        hasPendingStopwatchApplication = true
        let durations = Dictionary(uniqueKeysWithValues: recording.measurements.map { ($0.stepID, $0.templateSeconds) })
        rounds = rounds.map { round in
            var updated = round
            if let seconds = durations[round.id] { updated.durationSeconds = seconds }
            return updated
        }
        persistDraft()
    }

    /// A name-only plan becomes a new unsaved template after a complete recording.
    func applyNewStopwatchRoutine(_ recording: StopwatchRecording) throws {
        if let blocker = stopwatchApplyBlocker(recording, kind: .newTemplate) { throw blocker }
        hasPendingStopwatchApplication = true
        let durations = Dictionary(uniqueKeysWithValues: recording.measurements.map { ($0.stepID, $0.templateSeconds) })
        lastTemplateID = ""
        currentStarterID = nil
        unsavedTemplateID = recording.source.templateID
        gameTitle = recording.source.title
        rounds = recording.source.steps.enumerated().map { index, step in
            Round(id: step.id, name: step.name, color: .palette(index: index % Theme.ColorValue.timerPalette.count),
                  durationSeconds: durations[step.id] ?? Theme.TimerMechanic.minimumDuration,
                  orderIndex: index, countsAsPlayer: false)
        }
        roundCount = 1
        expandedRoundId = nil
        // Preserve the prior clean snapshot: Apply is an edit, never a save.
        persistDraft()
    }

    // MARK: - File I/O

    func save(to url: URL) -> (Bool, [ParseError]) {
        let game = buildGameSequence()
        let errors = validationErrors(for: game)
        guard errors.isEmpty else { return (false, errors) }

        do {
            if url.pathExtension.lowercased() == TemplateImportExport.fileExtension {
                let document = templateLibrary.exportDocument(for: game, templateID: currentSavedTemplateID)
                try TemplateDocumentCodec().write(document, to: url)
            } else {
                let content = parser.serialize(game)
                try content.write(to: url, atomically: true, encoding: .utf8)
            }
            return (true, [])
        } catch {
            return (false, [ParseError("Failed to save: \(error.localizedDescription)")])
        }
    }

    func saveToDocuments(isProUnlocked: Bool) -> TemplateSaveResult {
        refreshSavedTemplates()
        let game = buildGameSequence()
        let errors = validationErrors(for: game)
        guard errors.isEmpty else { return .failed(errors) }

        let existingTemplateID = currentSavedTemplateID
        let isUpdatingExistingTemplate = existingTemplateID.map { id in
            savedTemplates.contains { $0.id == id }
        } ?? false

        guard TemplateSavePolicy.canSaveTemplate(
            isProUnlocked: isProUnlocked,
            existingTemplateCount: savedTemplates.count,
            isUpdatingExistingTemplate: isUpdatingExistingTemplate
        ) else {
            return .requiresPro
        }

        do {
            let savedTemplate = try templateLibrary.save(game: game, templateID: existingTemplateID ?? stopwatchTemplateID)
            lastTemplateID = savedTemplate.id.uuidString
            lastGameFileName = ""
            currentStarterID = nil
            refreshSavedTemplates()
            markClean()
            return .saved
        } catch {
            return .failed([ParseError("Failed to save: \(error.localizedDescription)")])
        }
    }

    /// Saves silently — no alert. Called automatically when tapping Play.
    func autoSave() {
        refreshSavedTemplates()
        let game = buildGameSequence()
        guard validationErrors(for: game).isEmpty else { return }

        let existingTemplateID = currentSavedTemplateID
        let shouldCreateFirstTemplate = existingTemplateID == nil && savedTemplates.isEmpty
        guard existingTemplateID != nil || shouldCreateFirstTemplate else { return }

        do {
            let savedTemplate = try templateLibrary.save(game: game, templateID: existingTemplateID ?? stopwatchTemplateID)
            lastTemplateID = savedTemplate.id.uuidString
            lastGameFileName = ""
            currentStarterID = nil
            refreshSavedTemplates()
            markClean()
        } catch {
            return
        }
    }

    /// Tries to load the most recently saved game. Returns true if successful.
    func loadLastGame() -> Bool {
        refreshSavedTemplates()
        if let id = currentSavedTemplateID,
           savedTemplates.contains(where: { $0.id == id }) {
            do {
                let document = try templateLibrary.loadDocument(id: id)
                applyDocument(document)
                return true
            } catch {
                return false
            }
        }

        if let firstTemplate = savedTemplates.first {
            return applySavedTemplate(firstTemplate).0
        }

        guard !lastGameFileName.isEmpty else { return false }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(lastGameFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let (_, errors) = load(from: url)
        return errors.isEmpty
    }

    func load(from url: URL) -> (Bool, [ParseError]) {
        do {
            if url.pathExtension.lowercased() == TemplateImportExport.fileExtension {
                let document = try TemplateDocumentCodec().decode(from: url)
                applyDocument(document)
                return (true, [])
            }

            let content = try String(contentsOf: url, encoding: .utf8)
            let (game, errors) = parser.parse(content)
            guard errors.isEmpty else { return (false, errors) }

            applyGame(game, title: game.title)
            return (errors.isEmpty, errors)
        } catch {
            return (false, [ParseError("Failed to load: \(error.localizedDescription)")])
        }
    }

    func importTemplate(from url: URL, isProUnlocked: Bool) -> TemplateImportResult {
        refreshSavedTemplates()
        guard TemplateSavePolicy.canSaveTemplate(
            isProUnlocked: isProUnlocked,
            existingTemplateCount: savedTemplates.count,
            isUpdatingExistingTemplate: false
        ) else {
            return .requiresPro
        }

        do {
            let savedTemplate = try templateLibrary.importTemplate(from: url)
            refreshSavedTemplates()
            _ = applySavedTemplate(savedTemplate)
            return .imported(savedTemplate)
        } catch {
            return .failed([ParseError("Failed to import: \(error.localizedDescription)")])
        }
    }

    func exportCurrentTemplateURL() -> URL? {
        let game = buildGameSequence()
        guard validationErrors(for: game).isEmpty else { return nil }

        let document = templateLibrary.exportDocument(for: game, templateID: currentSavedTemplateID)
        return try? TemplateImportExport.exportURL(for: document)
    }

    func refreshSavedTemplates() {
        let templates = templateLibrary.listTemplates()
        savedTemplates = templates
        var segments: [UUID: [SequenceSegment]] = [:]
        for template in templates {
            if let document = try? templateLibrary.loadDocument(id: template.id) {
                segments[template.id] = document.game.segments
            }
        }
        savedTemplateSegments = segments
        publishWidgetSnapshots(for: templates)
        publishWatchTemplates(for: templates)
    }

    func setWidgetPublishingEnabled(_ isEnabled: Bool) {
        guard isWidgetPublishingEnabled != isEnabled else { return }
        isWidgetPublishingEnabled = isEnabled
        publishWidgetSnapshots(for: savedTemplates)
        publishWatchTemplates(for: savedTemplates)
    }

    // MARK: - Private

    private func publishWidgetSnapshots(for templates: [SavedTemplate]) {
        let templatesToPublish = isWidgetPublishingEnabled ? templates : []
        guard (try? widgetSnapshotStore.writeSnapshots(
            savedTemplates: templatesToPublish,
            isProUnlocked: isWidgetPublishingEnabled
        )) != nil else { return }
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "TemplateStartWidget")
#endif
    }

    /// Publishes full games locally and to the paired Watch. The existing Pro
    /// flag also sends an empty snapshot when access is revoked.
    private func publishWatchTemplates(for templates: [SavedTemplate]) {
        let templatesToPublish = isWidgetPublishingEnabled ? templates : []
        let watchTemplates = templatesToPublish.compactMap { saved -> WatchTemplate? in
            guard let document = try? templateLibrary.loadDocument(id: saved.id) else { return nil }
            return WatchTemplate(
                templateID: saved.id,
                title: saved.title,
                game: document.game,
                modifiedAt: saved.modifiedAt
            )
        }
        _ = try? watchTemplateStore.write(templates: watchTemplates)
        watchTemplatePublisher(watchTemplates)
    }

    private func reindex() {
        for i in rounds.indices {
            rounds[i].orderIndex = i
        }
    }

    private func validationErrors(for game: GameSequence) -> [ParseError] {
        game.activeRounds.isEmpty ? [ParseError("Add at least one active round before saving.")] : []
    }

    private func applyDocument(_ document: TurnTimerTemplateDocument) {
        applyGame(document.game, title: document.title)
        lastTemplateID = document.templateID.uuidString
        markClean()
    }

    private func applyGame(_ game: GameSequence, title: String) {
        var game = game
        game.normalizeTemplateFields()
        lastTemplateID = ""
        unsavedTemplateID = UUID()
        gameTitle = title
        rounds = game.rounds
        roundCount = game.roundCount
        expandedRoundId = nil
        currentStarterID = nil
        markClean()
    }

    private func migrateLegacyTemplateIfNeeded() {
        guard !hasMigratedLegacyTemplateLibrary else { return }
        defer { hasMigratedLegacyTemplateLibrary = true }

        do {
            if let migratedTemplate = try templateLibrary.migrateLegacyTemplateIfNeeded(fileName: lastGameFileName) {
                lastTemplateID = migratedTemplate.id.uuidString
                lastGameFileName = ""
                refreshSavedTemplates()
            }
        } catch {
            return
        }
    }
}

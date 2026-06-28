import SwiftUI
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

final class GameEditorViewModel: ObservableObject {

    @Published var gameTitle: String = "New Game"
    @Published var rounds: [Round] = []
    @Published var roundCount: Int = 1
    @Published var expandedRoundId: UUID?
    @Published private(set) var savedTemplates: [SavedTemplate] = []

    @AppStorage("lastGameFileName") private var lastGameFileName: String = ""
    @AppStorage("lastTemplateID") private var lastTemplateID: String = ""
    @AppStorage("hasMigratedLegacyTemplateLibrary") private var hasMigratedLegacyTemplateLibrary: Bool = false

    private let parser = GameFileParser()
    private let templateLibrary: TemplateLibraryStore
    private let widgetSnapshotStore: WidgetSnapshotStore
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
        widgetSnapshotStore: WidgetSnapshotStore = WidgetSnapshotStore()
    ) {
        self.templateLibrary = templateLibrary
        self.widgetSnapshotStore = widgetSnapshotStore
    }

    var isExpanded: Bool { expandedRoundId != nil }

    var currentSavedTemplateID: UUID? {
        UUID(uuidString: lastTemplateID)
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
        game.reindexRounds()
        gameTitle = game.title
        rounds = game.rounds
        roundCount = game.roundCount
        expandedRoundId = nil
        lastTemplateID = ""
    }

    func applySavedTemplate(_ template: SavedTemplate) -> (Bool, [ParseError]) {
        do {
            let document = try templateLibrary.loadDocument(id: template.id)
            applyDocument(document)
            lastTemplateID = template.id.uuidString
            return (true, [])
        } catch {
            return (false, [ParseError("Failed to load template: \(error.localizedDescription)")])
        }
    }

    func loadInitialTemplateIfNeeded() {
        refreshSavedTemplates()
        migrateLegacyTemplateIfNeeded()
        guard rounds.isEmpty else { return }
        if loadLastGame() { return }
        applyStarterTemplate(StarterTemplateLibrary.defaultTemplate)
    }

    // MARK: - Build Sequence

    func buildGameSequence() -> GameSequence {
        var game = GameSequence(title: gameTitle, rounds: rounds, roundCount: roundCount)
        game.reindexRounds()
        return game
    }

    // MARK: - File I/O

    func save(to url: URL) -> (Bool, [ParseError]) {
        let game = buildGameSequence()
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
            let savedTemplate = try templateLibrary.save(game: buildGameSequence(), templateID: existingTemplateID)
            lastTemplateID = savedTemplate.id.uuidString
            lastGameFileName = ""
            refreshSavedTemplates()
            return .saved
        } catch {
            return .failed([ParseError("Failed to save: \(error.localizedDescription)")])
        }
    }

    /// Saves silently — no alert. Called automatically when tapping Play.
    func autoSave() {
        refreshSavedTemplates()
        let existingTemplateID = currentSavedTemplateID
        let shouldCreateFirstTemplate = existingTemplateID == nil && savedTemplates.isEmpty
        guard existingTemplateID != nil || shouldCreateFirstTemplate else { return }

        do {
            let savedTemplate = try templateLibrary.save(game: buildGameSequence(), templateID: existingTemplateID)
            lastTemplateID = savedTemplate.id.uuidString
            lastGameFileName = ""
            refreshSavedTemplates()
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
            self.gameTitle = game.title
            self.rounds = game.rounds
            self.roundCount = game.roundCount
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
        let document = templateLibrary.exportDocument(for: buildGameSequence(), templateID: currentSavedTemplateID)
        return try? TemplateImportExport.exportURL(for: document)
    }

    func refreshSavedTemplates() {
        let templates = templateLibrary.listTemplates()
        savedTemplates = templates
        publishWidgetSnapshots(for: templates)
    }

    func setWidgetPublishingEnabled(_ isEnabled: Bool) {
        guard isWidgetPublishingEnabled != isEnabled else { return }
        isWidgetPublishingEnabled = isEnabled
        publishWidgetSnapshots(for: savedTemplates)
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

    private func reindex() {
        for i in rounds.indices {
            rounds[i].orderIndex = i
        }
    }

    private func applyDocument(_ document: TurnTimerTemplateDocument) {
        var game = document.game
        game.reindexRounds()
        gameTitle = document.title
        rounds = game.rounds
        roundCount = game.roundCount
        expandedRoundId = nil
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

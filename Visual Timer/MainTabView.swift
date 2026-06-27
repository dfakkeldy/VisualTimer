import SwiftUI

struct MainTabView: View {

    @StateObject private var gameViewModel: GameViewModel
    @StateObject private var soundManager: SoundManager
    @StateObject private var gameEditorViewModel: GameEditorViewModel
    @StateObject private var historyViewModel: HistoryViewModel
    @StateObject private var proAccess: ProAccessViewModel
    @StateObject private var templateSync: TemplateCloudSyncEngine
    @StateObject private var ubiquitousSettingsStore: UbiquitousSettingsStore
    @StateObject private var favoriteTemplates: FavoriteTemplateStore

    @State private var selectedTab = 0
    @State private var showTemplateStartError = false
    @State private var templateStartErrorMessage = ""

    private var timerViewModel: TimerViewModel { gameViewModel.timerViewModel }
    private let templateWidgetUpdater: TemplateWidgetUpdater
    private let widgetStore: TemplateWidgetStore

    init() {
        let tvm = TimerViewModel()
        let settingsStore = UbiquitousSettingsStore()
        let templateLibrary = TemplateLibraryStore()
        let syncEngine = TemplateCloudSyncEngine(templateLibrary: templateLibrary)
        let widgetStore = TemplateWidgetStore()
        let sm = SoundManager(ubiquitousSettingsStore: settingsStore)
        self.widgetStore = widgetStore
        self.templateWidgetUpdater = TemplateWidgetUpdater(templateLibrary: templateLibrary, widgetStore: widgetStore)
        _soundManager = StateObject(wrappedValue: sm)
        _gameViewModel = StateObject(wrappedValue: GameViewModel(timerViewModel: tvm, soundManager: sm))
        _gameEditorViewModel = StateObject(wrappedValue: GameEditorViewModel(templateLibrary: templateLibrary))
        _historyViewModel = StateObject(wrappedValue: HistoryViewModel())
        _proAccess = StateObject(wrappedValue: ProAccessViewModel())
        _templateSync = StateObject(wrappedValue: syncEngine)
        _ubiquitousSettingsStore = StateObject(wrappedValue: settingsStore)
        _favoriteTemplates = StateObject(wrappedValue: FavoriteTemplateStore())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GamePlaybackView(
                timerViewModel: timerViewModel,
                gameViewModel: gameViewModel,
                soundManager: soundManager,
                proAccess: proAccess,
                templateSync: templateSync
            )
            .tabItem {
                Label(Theme.Tab.timerTabTitle, systemImage: Theme.Tab.timerTabSymbol)
            }
            .tag(0)

            GameEditorView(
                editor: gameEditorViewModel,
                proAccess: proAccess,
                templateSync: templateSync,
                favoriteTemplates: favoriteTemplates,
                onPlayGame: { game in
                    gameViewModel.loadGame(game)
                    gameViewModel.startGame()
                    selectedTab = 0
                }
            )
            .tabItem {
                Label(Theme.Tab.editorTabTitle, systemImage: Theme.Tab.editorTabSymbol)
            }
            .tag(1)

            HistoryView(history: historyViewModel, proAccess: proAccess)
                .tabItem {
                    Label(Theme.Tab.historyTabTitle, systemImage: Theme.Tab.historyTabSymbol)
            }
            .tag(2)
        }
        .task {
            gameEditorViewModel.refreshSavedTemplates()
            consumePendingWidgetStart()
            refreshWidgetSnapshots()
        }
        .task(id: proAccess.isProUnlocked) {
            await templateSync.setEnabled(proAccess.isProUnlocked)
        }
        .onChange(of: gameEditorViewModel.savedTemplates) { _, templates in
            favoriteTemplates.removeMissingFavorite(from: templates)
            refreshWidgetSnapshots(savedTemplates: templates)
            guard proAccess.isProUnlocked else { return }
            templateSync.queueLocalTemplates(templates)
        }
        .onChange(of: favoriteTemplates.favoriteTemplateID) { _, _ in
            refreshWidgetSnapshots()
        }
        .onChange(of: templateSync.changeRevision) { _, _ in
            gameEditorViewModel.refreshSavedTemplates()
            refreshWidgetSnapshots()
        }
        .onOpenURL(perform: handleWidgetURL)
        .alert("Template Unavailable", isPresented: $showTemplateStartError) {
            Button("OK") {}
        } message: {
            Text(templateStartErrorMessage)
        }
    }

    private func refreshWidgetSnapshots(savedTemplates: [SavedTemplate]? = nil) {
        let templates = savedTemplates ?? gameEditorViewModel.savedTemplates
        templateWidgetUpdater.refresh(
            savedTemplates: templates,
            favoriteTemplateID: favoriteTemplates.favoriteTemplateID
        )
    }

    private func consumePendingWidgetStart() {
        guard let templateID = widgetStore.consumePendingStartTemplateID() else { return }
        startTemplateFromWidget(idString: templateID)
    }

    private func handleWidgetURL(_ url: URL) {
        guard url.scheme == "turntimer" else { return }

        if url.host == "templates" {
            selectedTab = 1
            return
        }

        guard url.host == "start",
              let templateID = url.pathComponents.dropFirst().first
        else {
            return
        }
        startTemplateFromWidget(idString: templateID)
    }

    private func startTemplateFromWidget(idString: String) {
        guard let templateID = UUID(uuidString: idString) else {
            presentTemplateStartError("That widget shortcut no longer points to a valid template.")
            selectedTab = 1
            return
        }

        let result = gameEditorViewModel.applySavedTemplate(id: templateID)
        guard result.0 else {
            presentTemplateStartError(result.1.map(\.message).joined(separator: "\n"))
            selectedTab = 1
            return
        }

        gameViewModel.loadGame(gameEditorViewModel.buildGameSequence())
        gameViewModel.startGame()
        selectedTab = 0
    }

    private func presentTemplateStartError(_ message: String) {
        templateStartErrorMessage = message
        showTemplateStartError = true
    }
}

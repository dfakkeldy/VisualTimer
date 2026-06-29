import SwiftUI

struct MainTabView: View {

    @StateObject private var gameViewModel: GameViewModel
    @StateObject private var soundManager: SoundManager
    @StateObject private var gameEditorViewModel: GameEditorViewModel
    @StateObject private var historyViewModel: HistoryViewModel
    @StateObject private var proAccess: ProAccessViewModel
    @StateObject private var templateSync: TemplateCloudSyncEngine
    @StateObject private var historySync: HistoryCloudSyncEngine
    @StateObject private var ubiquitousSettingsStore: UbiquitousSettingsStore

    @State private var selectedTab = 0

    private let templateLibrary: TemplateLibraryStore
    private var timerViewModel: TimerViewModel { gameViewModel.timerViewModel }

    init() {
        let tvm = TimerViewModel()
        let settingsStore = UbiquitousSettingsStore()
        let templateLibrary = TemplateLibraryStore()
        let historyStore = HistoryStore()
        let syncEngine = TemplateCloudSyncEngine(templateLibrary: templateLibrary)
        let historySyncEngine = HistoryCloudSyncEngine(historyStore: historyStore)
        let historyViewModel = HistoryViewModel(store: historyStore)
        let sm = SoundManager(ubiquitousSettingsStore: settingsStore)
        historyViewModel.onRecordDeleted = { [weak historySyncEngine] id in
            Task { @MainActor in
                historySyncEngine?.queueDeletedHistory(id: id)
            }
        }
        self.templateLibrary = templateLibrary
        _soundManager = StateObject(wrappedValue: sm)
        _gameViewModel = StateObject(wrappedValue: GameViewModel(
            timerViewModel: tvm,
            soundManager: sm,
            historyStore: historyStore,
            onHistoryRecordSaved: { [weak historyViewModel] record in
                historyViewModel?.recordSaved(record)
            }
        ))
        _gameEditorViewModel = StateObject(wrappedValue: GameEditorViewModel(templateLibrary: templateLibrary))
        _historyViewModel = StateObject(wrappedValue: historyViewModel)
        _proAccess = StateObject(wrappedValue: ProAccessViewModel())
        _templateSync = StateObject(wrappedValue: syncEngine)
        _historySync = StateObject(wrappedValue: historySyncEngine)
        _ubiquitousSettingsStore = StateObject(wrappedValue: settingsStore)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GamePlaybackView(
                timerViewModel: timerViewModel,
                gameViewModel: gameViewModel,
                soundManager: soundManager,
                proAccess: proAccess,
                templateSync: templateSync,
                historySync: historySync
            )
            .tabItem {
                Label(Theme.Tab.timerTabTitle, systemImage: Theme.Tab.timerTabSymbol)
            }
            .tag(0)

            GameEditorView(
                editor: gameEditorViewModel,
                proAccess: proAccess,
                templateSync: templateSync,
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
        .onOpenURL(perform: handleOpenURL)
        .task {
            gameEditorViewModel.refreshSavedTemplates()
        }
        .task(id: proAccess.isProUnlocked) {
            gameEditorViewModel.setWidgetPublishingEnabled(proAccess.isProUnlocked)
            await templateSync.setEnabled(proAccess.isProUnlocked)
            await historySync.setEnabled(proAccess.isProUnlocked)
        }
        .onChange(of: gameEditorViewModel.savedTemplates) { _, templates in
            guard proAccess.isProUnlocked else { return }
            templateSync.queueLocalTemplates(templates)
        }
        .onChange(of: historyViewModel.records) { _, records in
            guard proAccess.isProUnlocked else { return }
            historySync.queueLocalHistory(records)
        }
        .onChange(of: templateSync.changeRevision) { _, _ in
            gameEditorViewModel.refreshSavedTemplates()
        }
        .onChange(of: historySync.changeRevision) { _, _ in
            historyViewModel.loadRecords()
        }
    }

    private func handleOpenURL(_ url: URL) {
        guard let deepLink = TurnTimerDeepLink(url: url) else { return }

        switch deepLink {
        case .template(let id):
            startSavedTemplate(id: id)
        case .starter(let id):
            startStarterTemplate(id: id)
        }
    }

    private func startSavedTemplate(id: UUID) {
        guard let document = try? templateLibrary.loadDocument(id: id) else { return }
        startGame(document.game)
    }

    private func startStarterTemplate(id: String) {
        guard let template = StarterTemplateLibrary.template(id: id) else { return }
        startGame(template.game)
    }

    private func startGame(_ game: GameSequence) {
        gameViewModel.loadGame(game)
        gameViewModel.startGame()
        selectedTab = 0
    }
}

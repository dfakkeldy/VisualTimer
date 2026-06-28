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

    private var timerViewModel: TimerViewModel { gameViewModel.timerViewModel }

    init() {
        let tvm = TimerViewModel()
        let settingsStore = UbiquitousSettingsStore()
        let templateLibrary = TemplateLibraryStore()
        let historyStore = HistoryStore()
        let syncEngine = TemplateCloudSyncEngine(templateLibrary: templateLibrary)
        let historySyncEngine = HistoryCloudSyncEngine(historyStore: historyStore)
        let sm = SoundManager(ubiquitousSettingsStore: settingsStore)
        _soundManager = StateObject(wrappedValue: sm)
        _gameViewModel = StateObject(wrappedValue: GameViewModel(timerViewModel: tvm, soundManager: sm))
        _gameEditorViewModel = StateObject(wrappedValue: GameEditorViewModel(templateLibrary: templateLibrary))
        _historyViewModel = StateObject(wrappedValue: HistoryViewModel(store: historyStore))
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
        .task(id: proAccess.isProUnlocked) {
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
}

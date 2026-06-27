import SwiftUI

struct MainTabView: View {

    @StateObject private var gameViewModel: GameViewModel
    @StateObject private var soundManager = SoundManager()
    @StateObject private var gameEditorViewModel = GameEditorViewModel()
    @StateObject private var historyViewModel: HistoryViewModel
    @StateObject private var proAccess: ProAccessViewModel

    @State private var selectedTab = 0

    private var timerViewModel: TimerViewModel { gameViewModel.timerViewModel }

    init() {
        let tvm = TimerViewModel()
        let sm = SoundManager()
        _soundManager = StateObject(wrappedValue: sm)
        _gameViewModel = StateObject(wrappedValue: GameViewModel(timerViewModel: tvm, soundManager: sm))
        _gameEditorViewModel = StateObject(wrappedValue: GameEditorViewModel())
        _historyViewModel = StateObject(wrappedValue: HistoryViewModel())
        _proAccess = StateObject(wrappedValue: ProAccessViewModel())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GamePlaybackView(
                timerViewModel: timerViewModel,
                gameViewModel: gameViewModel,
                soundManager: soundManager,
                proAccess: proAccess
            )
            .tabItem {
                Label(Theme.Tab.timerTabTitle, systemImage: Theme.Tab.timerTabSymbol)
            }
            .tag(0)

            GameEditorView(
                editor: gameEditorViewModel,
                proAccess: proAccess,
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
    }
}

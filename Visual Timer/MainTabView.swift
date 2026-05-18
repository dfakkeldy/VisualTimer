import SwiftUI

struct MainTabView: View {

    @StateObject private var gameViewModel: GameViewModel
    @StateObject private var soundManager = SoundManager()
    @StateObject private var gameEditorViewModel = GameEditorViewModel()

    @State private var selectedTab = 0

    private var timerViewModel: TimerViewModel { gameViewModel.timerViewModel }

    init() {
        let tvm = TimerViewModel()
        _gameViewModel = StateObject(wrappedValue: GameViewModel(timerViewModel: tvm))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GamePlaybackView(
                timerViewModel: timerViewModel,
                gameViewModel: gameViewModel,
                soundManager: soundManager
            )
            .tabItem {
                Label(Theme.Tab.timerTabTitle, systemImage: Theme.Tab.timerTabSymbol)
            }
            .tag(0)

            GameEditorView(
                editor: gameEditorViewModel,
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
        }
    }
}

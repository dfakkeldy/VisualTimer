import SwiftUI

struct MainTabView: View {

    @StateObject private var timerViewModel = TimerViewModel()
    @StateObject private var gameViewModel: GameViewModel
    @StateObject private var soundManager = SoundManager()

    @State private var selectedTab = 0

    init() {
        let tvm = TimerViewModel()
        _timerViewModel = StateObject(wrappedValue: tvm)
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
                editor: GameEditorViewModel(),
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

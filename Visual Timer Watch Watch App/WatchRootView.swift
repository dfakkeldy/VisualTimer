import SwiftUI

/// Root watchOS view: browse a quick timer, starter templates, and saved
/// templates published by the iOS app. Selecting a template loads it into a
/// shared `GameViewModel` and presents `WatchGamePlaybackView`.
struct WatchRootView: View {

    @StateObject private var gameViewModel: GameViewModel
    @StateObject private var timerViewModel: TimerViewModel
    @StateObject private var soundManager = SoundManager()

    @State private var savedTemplates: [WatchTemplate] = []
    @State private var presentingGame = false

    init() {
        let timer = TimerViewModel()
        _timerViewModel = StateObject(wrappedValue: timer)
        _gameViewModel = StateObject(wrappedValue: GameViewModel(timerViewModel: timer))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        WatchTimerView()
                    } label: {
                        Label("Quick Timer", systemImage: "timer")
                    }
                }

                Section("Starter Templates") {
                    ForEach(StarterTemplateLibrary.templates) { template in
                        Button {
                            startGame(template.game)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(template.title)
                                Text(template.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !savedTemplates.isEmpty {
                    Section("Saved Templates") {
                        ForEach(savedTemplates) { template in
                            Button {
                                startGame(template.game)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(template.title)
                                    Text(durationText(for: template.game))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $presentingGame) {
                WatchGamePlaybackView(
                    gameViewModel: gameViewModel,
                    timerViewModel: timerViewModel,
                    soundManager: soundManager
                )
            }
        }
        .task { refreshSavedTemplates() }
    }

    // MARK: - Launch

    private func startGame(_ game: GameSequence) {
        gameViewModel.loadGame(game)
        gameViewModel.startGame()
        presentingGame = true
    }

    // MARK: - Saved templates (App Group)

    private func refreshSavedTemplates() {
        let store = WatchTemplateStore()
        savedTemplates = (try? store.read()) ?? []
    }

    private func durationText(for game: GameSequence) -> String {
        let sequenceSeconds = game.activeRounds.reduce(0) { $0 + $1.durationSeconds }
        let total = sequenceSeconds * max(game.roundCount, 1)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d • %d round(s)", minutes, seconds, game.activeRounds.count)
    }
}

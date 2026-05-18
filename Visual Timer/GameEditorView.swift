import SwiftUI

struct GameEditorView: View {

    @ObservedObject var editor: GameEditorViewModel
    let onPlayGame: (GameSequence) -> Void

    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                titleField
                roundsList
            }
            .background(Theme.ColorValue.appBackground)
            .navigationTitle("Game Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Play") {
                        let game = editor.buildGameSequence()
                        onPlayGame(game)
                    }
                    .disabled(editor.rounds.isEmpty)
                }
            }
            .alert("Save Status", isPresented: $showSaveAlert) {
                Button("OK") {}
            } message: {
                Text(saveAlertMessage)
            }
        }
    }

    // MARK: - Title Field

    private var titleField: some View {
        HStack {
            TextField("Game Title", text: $editor.gameTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.ColorValue.textPrimary)
                .focused($titleFocused)

            Spacer()

            Button("Save") {
                saveGame()
            }
            .font(.body.weight(.medium))
        }
        .padding(.horizontal, Theme.Dimension.screenHorizontalPadding)
        .padding(.vertical, 12)
    }

    // MARK: - Rounds List

    private var roundsList: some View {
        List {
            Section {
                ForEach(editor.rounds) { round in
                    if editor.expandedRoundId == round.id {
                        PlayerEditView(
                            round: binding(for: round),
                            onDismiss: { editor.expandedRoundId = nil }
                        )
                        .listRowBackground(Theme.ColorValue.circleBackground)
                    } else {
                        PlayerRowView(
                            round: round,
                            onTap: { editor.toggleExpanded(id: round.id) },
                            onToggleActive: { editor.toggleActive(id: round.id) },
                            onDelete: { editor.deleteRound(id: round.id) }
                        )
                        .listRowBackground(Theme.ColorValue.circleBackground)
                    }
                }
                .onMove(perform: editor.moveRounds)

                // Add Round button
                Button {
                    editor.addRound()
                } label: {
                    Label(Theme.Label.addRound, systemImage: Theme.Symbol.increment)
                }
                .listRowBackground(Theme.ColorValue.circleBackground)
            } header: {
                Text("Rounds (\(editor.rounds.count))")
                    .font(.system(size: Theme.Editor.sectionHeaderFontSize))
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Helpers

    private func binding(for round: Round) -> Binding<Round> {
        Binding(
            get: { editor.rounds.first(where: { $0.id == round.id }) ?? round },
            set: { newValue in
                if let index = editor.rounds.firstIndex(where: { $0.id == round.id }) {
                    editor.rounds[index] = newValue
                }
            }
        )
    }

    private func saveGame() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("\(editor.gameTitle).vtgame")
        let (success, errors) = editor.save(to: url)
        if success {
            saveAlertMessage = "Saved to Documents."
        } else {
            saveAlertMessage = errors.map(\.message).joined(separator: "\n")
        }
        showSaveAlert = true
    }
}

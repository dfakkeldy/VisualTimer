import SwiftUI

struct GameEditorView: View {

    @ObservedObject var editor: GameEditorViewModel
    @ObservedObject var proAccess: ProAccessViewModel
    let onPlayGame: (GameSequence) -> Void

    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var requestedProFeature: ProFeature?
    @FocusState private var titleFocused: Bool

    private var editingRound: Round? {
        guard let id = editor.expandedRoundId else { return nil }
        return editor.rounds.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                titleField
                starterTemplates
                roundCountStepper
                roundsList
            }
            .background(Theme.ColorValue.appBackground)
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        editor.autoSave()
                        let game = editor.buildGameSequence()
                        onPlayGame(game)
                    }
                    .disabled(editor.rounds.isEmpty)
                }
            }
            .onAppear {
                editor.loadInitialTemplateIfNeeded()
            }
            .alert("Save Status", isPresented: $showSaveAlert) {
                Button("OK") {}
            } message: {
                Text(saveAlertMessage)
            }
            .sheet(item: $requestedProFeature) { feature in
                ProPaywallView(feature: feature, proAccess: proAccess)
            }
            .sheet(item: Binding(
                get: { editingRound },
                set: { _ in editor.expandedRoundId = nil }
            )) { round in
                PlayerEditSheet(
                    round: round,
                    onUpdateName: { editor.updateName(id: round.id, name: $0) },
                    onUpdateColor: { editor.updateColor(id: round.id, color: $0) },
                    onUpdateSound: { editor.updateSound(id: round.id, sound: $0) },
                    onUpdateEmoji: { editor.updateEmoji(id: round.id, emoji: $0) },
                    onUpdateDuration: { editor.updateDuration(id: round.id, duration: $0) },
                    onToggleStartPaused: { editor.toggleStartPaused(id: round.id) },
                    onUpdateCountsAsPlayer: { editor.updateCountsAsPlayer(id: round.id, countsAsPlayer: $0) },
                    onDismiss: { editor.expandedRoundId = nil }
                )
            }
        }
    }

    // MARK: - Title Field

    private var titleField: some View {
        HStack {
            TextField("Template Name", text: $editor.gameTitle)
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

    private var starterTemplates: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(StarterTemplateLibrary.templates) { template in
                    Button {
                        editor.applyStarterTemplate(template)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ColorValue.textPrimary)
                            Text(template.subtitle)
                                .font(.caption)
                                .foregroundStyle(Theme.ColorValue.textSecondary)
                                .lineLimit(2)
                        }
                        .frame(width: 150, alignment: .leading)
                        .padding(12)
                        .background(Theme.ColorValue.circleBackground)
                        .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Dimension.screenHorizontalPadding)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Round Count Stepper

    private var roundCountStepper: some View {
        HStack {
            Text("Repeat Sequence")
                .foregroundStyle(Theme.ColorValue.textSecondary)
            Spacer()
            Button {
                editor.roundCount = max(1, editor.roundCount - 1)
            } label: {
                Image(systemName: Theme.Symbol.decrement)
            }
            Text("\(editor.roundCount)")
                .monospacedDigit()
                .foregroundStyle(Theme.ColorValue.textPrimary)
                .frame(minWidth: 24)
            Button {
                editor.roundCount += 1
            } label: {
                Image(systemName: Theme.Symbol.increment)
            }
        }
        .padding(.horizontal, Theme.Dimension.screenHorizontalPadding)
        .padding(.vertical, 8)
    }

    // MARK: - Rounds List

    private var roundsList: some View {
        List {
            Section {
                ForEach(editor.rounds) { round in
                    PlayerRowView(
                        round: round,
                        onTap: { editor.expandedRoundId = round.id },
                        onToggleActive: { editor.toggleActive(id: round.id) },
                        onDelete: { editor.deleteRound(id: round.id) }
                    )
                    .listRowBackground(Theme.ColorValue.circleBackground)
                }
                .onMove(perform: editor.moveRounds)

                // Add Round button
                Button {
                    editor.addRound()
                } label: {
                    Label(Theme.Label.addPlayer, systemImage: Theme.Symbol.addPlayer)
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

    private func saveGame() {
        let result = editor.saveToDocuments(isProUnlocked: proAccess.isProUnlocked)
        switch result {
        case .saved:
            saveAlertMessage = "Template saved to Documents."
            showSaveAlert = true
        case .requiresPro:
            requestedProFeature = .unlimitedTemplates
        case .failed(let errors):
            saveAlertMessage = errors.map(\.message).joined(separator: "\n")
            showSaveAlert = true
        }
    }
}

// MARK: - Player Edit Sheet

private struct PlayerEditSheet: View {
    let round: Round
    let onUpdateName: (String) -> Void
    let onUpdateColor: (RoundColor) -> Void
    let onUpdateSound: (TimerSound) -> Void
    let onUpdateEmoji: (String) -> Void
    let onUpdateDuration: (Int) -> Void
    let onToggleStartPaused: () -> Void
    let onUpdateCountsAsPlayer: (Bool) -> Void
    let onDismiss: () -> Void

    @State private var nameText: String
    @State private var emojiText: String
    @State private var selectedSound: TimerSound
    @State private var startPaused: Bool
    @State private var countsAsPlayer: Bool
    @State private var selectedColorIndex: Int
    @State private var localDuration: Int

    init(
        round: Round,
        onUpdateName: @escaping (String) -> Void,
        onUpdateColor: @escaping (RoundColor) -> Void,
        onUpdateSound: @escaping (TimerSound) -> Void,
        onUpdateEmoji: @escaping (String) -> Void,
        onUpdateDuration: @escaping (Int) -> Void,
        onToggleStartPaused: @escaping () -> Void,
        onUpdateCountsAsPlayer: @escaping (Bool) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.round = round
        self.onUpdateName = onUpdateName
        self.onUpdateColor = onUpdateColor
        self.onUpdateSound = onUpdateSound
        self.onUpdateEmoji = onUpdateEmoji
        self.onUpdateDuration = onUpdateDuration
        self.onToggleStartPaused = onToggleStartPaused
        self.onUpdateCountsAsPlayer = onUpdateCountsAsPlayer
        self.onDismiss = onDismiss
        _nameText = State(initialValue: round.name)
        _emojiText = State(initialValue: round.emoji)
        _selectedSound = State(initialValue: round.sound)
        _startPaused = State(initialValue: round.startPaused)
        if case .palette(let index) = round.color {
            _selectedColorIndex = State(initialValue: index)
        } else {
            _selectedColorIndex = State(initialValue: 0)
        }
        _localDuration = State(initialValue: round.durationSeconds)
        _countsAsPlayer = State(initialValue: round.countsAsPlayer)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.caption)
                            .foregroundStyle(Theme.ColorValue.textSecondary)
                        TextField("Round name", text: $nameText)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: nameText) { _, newValue in
                                onUpdateName(newValue)
                            }
                    }

                    // Color picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.caption)
                            .foregroundStyle(Theme.ColorValue.textSecondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Editor.colorSwatchSpacing), count: 8), spacing: Theme.Editor.colorSwatchSpacing) {
                            ForEach(0..<Theme.ColorValue.timerPalette.count, id: \.self) { index in
                                let color = Theme.ColorValue.timerPalette[index]
                                Circle()
                                    .fill(color)
                                    .frame(width: Theme.Editor.colorSwatchSize, height: Theme.Editor.colorSwatchSize)
                                    .overlay {
                                        if selectedColorIndex == index {
                                            Circle()
                                                .strokeBorder(.white, lineWidth: 3)
                                        }
                                    }
                                    .onTapGesture {
                                        selectedColorIndex = index
                                        onUpdateColor(.palette(index: index))
                                    }
                            }
                        }
                    }

                    // Sound picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sound")
                            .font(.caption)
                            .foregroundStyle(Theme.ColorValue.textSecondary)
                        Picker("Sound", selection: $selectedSound) {
                            ForEach(TimerSound.allCases, id: \.self) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedSound) { _, newValue in
                            onUpdateSound(newValue)
                        }
                    }

                    // Emoji field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Emoji")
                            .font(.caption)
                            .foregroundStyle(Theme.ColorValue.textSecondary)
                        TextField("🎮", text: $emojiText)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: emojiText) { _, newValue in
                                onUpdateEmoji(newValue)
                            }
                    }

                    // Duration stepper
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Time")
                            .font(.caption)
                            .foregroundStyle(Theme.ColorValue.textSecondary)
                        HStack(spacing: 16) {
                            Button {
                                let newDuration = max(Theme.TimerMechanic.minimumDuration,
                                    localDuration - Theme.TimerMechanic.durationStep)
                                localDuration = newDuration
                                onUpdateDuration(newDuration)
                            } label: {
                                Image(systemName: Theme.Symbol.decrement)
                                    .font(.title3)
                            }

                            Text(durationDisplay)
                                .font(.title3.monospacedDigit())
                                .foregroundStyle(Theme.ColorValue.textPrimary)
                                .frame(minWidth: 80)

                            Button {
                                let newDuration = localDuration + Theme.TimerMechanic.durationStep
                                localDuration = newDuration
                                onUpdateDuration(newDuration)
                            } label: {
                                Image(systemName: Theme.Symbol.increment)
                                    .font(.title3)
                            }
                        }
                    }

                    // Start paused toggle
                    Toggle(isOn: $startPaused) {
                        Label(Theme.Label.startPaused, systemImage: Theme.Symbol.startPaused)
                    }
                    .toggleStyle(.switch)
                    .onChange(of: startPaused) {
                        onToggleStartPaused()
                    }

                    // Counts as turn toggle
                    Toggle(isOn: $countsAsPlayer) {
                        Label("Counts as turn", systemImage: "person.fill")
                    }
                    .toggleStyle(.switch)
                    .onChange(of: countsAsPlayer) { _, newValue in
                        onUpdateCountsAsPlayer(newValue)
                    }
                }
                .padding()
            }
            .background(Theme.ColorValue.appBackground)
            .navigationTitle(round.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss() }
                        .font(.body.weight(.medium))
                }
            }
        }
    }

    private var durationDisplay: String {
        if localDuration >= 60 {
            let m = localDuration / 60
            let s = localDuration % 60
            return s > 0 ? "\(m)m \(s)s" : "\(m)m"
        }
        return "\(localDuration)s"
    }
}

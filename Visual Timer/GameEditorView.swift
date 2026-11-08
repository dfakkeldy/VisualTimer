import SwiftUI
import UniformTypeIdentifiers

struct GameEditorView: View {

    @ObservedObject var editor: GameEditorViewModel
    @ObservedObject var proAccess: ProAccessViewModel
    @ObservedObject var templateSync: TemplateCloudSyncEngine
    @ObservedObject var soundManager: SoundManager
    let onPlayGame: (GameSequence) -> Void

    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var requestedProFeature: ProFeature?
    @State private var showImportPicker = false
    @State private var shareItem: TemplateShareItem?
    @State private var pendingReplacement: PendingReplacement?
    @AppStorage(TimerAlertScheduler.enabledKey) private var alertsEnabled = false
    @State private var alertsDenied = false

    /// A template the person tapped while the current one has unsaved edits.
    private enum PendingReplacement: Identifiable {
        case saved(SavedTemplate)
        case starter(StarterTemplate)

        var id: String {
            switch self {
            case .saved(let template): return template.id.uuidString
            case .starter(let template): return template.id
            }
        }

        var title: String {
            switch self {
            case .saved(let template): return template.title
            case .starter(let template): return template.title
            }
        }
    }
    @FocusState private var titleFocused: Bool

    private var editingRound: Round? {
        guard let id = editor.expandedRoundId else { return nil }
        return editor.rounds.first(where: { $0.id == id })
    }

    private var currentGame: GameSequence { editor.buildGameSequence() }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    templatePicker
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    sectionHeader("Start from")
                }

                Section {
                    sequenceHeader
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 12, trailing: 20))
                }

                Section {
                    ForEach(editor.rounds) { round in
                        PlayerRowView(
                            round: round,
                            onTap: { editor.expandedRoundId = round.id },
                            onToggleActive: { editor.toggleActive(id: round.id) },
                            onDelete: { editor.deleteRound(id: round.id) }
                        )
                        .listRowBackground(Theme.ColorValue.surface)
                    }
                    .onMove(perform: editor.moveRounds)

                    Button {
                        editor.addRound()
                    } label: {
                        Label(Theme.Label.addPlayer, systemImage: Theme.Symbol.addPlayer)
                            .font(.body.weight(.medium))
                    }
                    .listRowBackground(Theme.ColorValue.surface)
                } header: {
                    sectionHeader("Rounds")
                } footer: {
                    Text("Tap a round to edit it. Touch and hold to reorder.")
                        .font(.caption)
                        .foregroundStyle(Theme.ColorValue.textTertiary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.ColorValue.appBackground)
            .contentMargins(.bottom, 16, for: .scrollContent)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                startBar
            }
            .confirmationDialog(
                "Replace your unsaved changes?",
                isPresented: Binding(get: { pendingReplacement != nil }, set: { if !$0 { pendingReplacement = nil } }),
                titleVisibility: .visible,
                presenting: pendingReplacement
            ) { replacement in
                Button("Open \(replacement.title)", role: .destructive) {
                    apply(replacement)
                }
                Button("Keep editing", role: .cancel) {}
            } message: { _ in
                Text("Your edits to “\(editor.gameTitle)” haven't been saved.")
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showImportPicker = true
                        } label: {
                            Label(Theme.Label.importTemplate, systemImage: Theme.Symbol.importTemplate)
                        }
                        Button {
                            exportCurrentTemplate()
                        } label: {
                            Label(Theme.Label.exportTemplate, systemImage: Theme.Symbol.exportTemplate)
                        }
                        .disabled(!editor.canSaveOrStartTemplate)
                    } label: {
                        Image(systemName: Theme.Symbol.more)
                    }
                    .accessibilityLabel("Import or export")
                }
            }
            .onAppear {
                editor.loadInitialTemplateIfNeeded()
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.turnTimerTemplate],
                allowsMultipleSelection: false,
                onCompletion: handleImportResult
            )
            .alert("Template", isPresented: $showSaveAlert) {
                Button("OK") {}
            } message: {
                Text(saveAlertMessage)
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
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
                    onPreviewSound: { soundManager.playPreview($0) },
                    onUpdateEmoji: { editor.updateEmoji(id: round.id, emoji: $0) },
                    onUpdateDuration: { editor.updateDuration(id: round.id, duration: $0) },
                    onToggleStartPaused: { editor.toggleStartPaused(id: round.id) },
                    onUpdateCountsAsPlayer: { editor.updateCountsAsPlayer(id: round.id, countsAsPlayer: $0) },
                    onDismiss: { editor.expandedRoundId = nil }
                )
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.ColorValue.textSecondary)
            .textCase(nil)
    }

    // MARK: - Sequence header

    private var sequenceHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                TextField("Template name", text: $editor.gameTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.ColorValue.textPrimary)
                    .focused($titleFocused)
                    .submitLabel(.done)

                saveControl
            }

            Text(summaryLine)
                .font(.subheadline)
                .foregroundStyle(Theme.ColorValue.textSecondary)

            SequenceRibbon(segments: currentGame.segments, height: 8)

            HStack {
                Text("Repeat")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                Spacer()
                GlassStepper(
                    value: "\(editor.roundCount)×",
                    decrementLabel: "Fewer repeats",
                    incrementLabel: "More repeats",
                    canDecrement: editor.roundCount > 1,
                    onDecrement: { editor.roundCount = max(1, editor.roundCount - 1) },
                    onIncrement: { editor.roundCount += 1 }
                )
            }
            .padding(.top, 4)

            TemplateSyncStatusView(syncEngine: templateSync, isProUnlocked: proAccess.isProUnlocked)
        }
    }

    private var summaryLine: String {
        let game = currentGame
        let rounds = TurnTimerCountText.label(for: game.activeRounds.count, singular: "round")
        let repeats = game.roundCount > 1 ? " × \(game.roundCount)" : ""
        return "\(rounds)\(repeats) · about \(TimerText.words(game.totalSeconds))"
    }

    @ViewBuilder
    private var saveControl: some View {
        if editor.isShowingSavedTemplate && !editor.hasUnsavedChanges {
            Text("Saved")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ColorValue.textTertiary)
        } else {
            Button {
                saveGame()
            } label: {
                Text(editor.isShowingSavedTemplate ? "Save changes" : "Save")
                    .font(.subheadline.weight(.semibold))
            }
            .disabled(!editor.canSaveOrStartTemplate)
            .accessibilityHint(editor.isShowingSavedTemplate ? "You have unsaved changes" : "Save as your own template")
        }
    }

    // MARK: - Template picker

    private var templatePicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(editor.savedTemplates) { template in
                    let isCurrent = editor.isShowingSavedTemplate && editor.currentSavedTemplateID == template.id
                    Button {
                        request(.saved(template))
                    } label: {
                        templateCard(
                            title: template.title,
                            detail: "Yours · about \(TimerText.words(template.totalSeconds))",
                            segments: editor.savedTemplateSegments[template.id] ?? [],
                            isCurrent: isCurrent
                        )
                    }
                    .buttonStyle(TimerPressStyle())
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                }

                ForEach(StarterTemplateLibrary.templates) { template in
                    let isCurrent = editor.currentStarterID == template.id
                    Button {
                        request(.starter(template))
                    } label: {
                        templateCard(
                            title: template.title,
                            detail: "Starter · about \(TimerText.words(template.game.totalSeconds))",
                            segments: template.game.segments,
                            isCurrent: isCurrent
                        )
                    }
                    .buttonStyle(TimerPressStyle())
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private func request(_ replacement: PendingReplacement) {
        if editor.hasUnsavedChanges {
            pendingReplacement = replacement
        } else {
            apply(replacement)
        }
    }

    private func apply(_ replacement: PendingReplacement) {
        switch replacement {
        case .saved(let template):
            loadSavedTemplate(template)
        case .starter(let template):
            editor.applyStarterTemplate(template)
        }
    }

    private func templateCard(title: String, detail: String, segments: [SequenceSegment], isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SequenceRibbon(segments: segments, height: 5)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ColorValue.textPrimary)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Theme.ColorValue.textSecondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(width: 148, alignment: .leading)
        .background(Theme.ColorValue.surface, in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isCurrent ? Theme.ColorValue.selectionAccent : Theme.ColorValue.surfaceStroke,
                              lineWidth: isCurrent ? 2 : 1)
        }
    }

    // MARK: - Start

    /// The alert choice sits where sessions begin (the hook by the door), as
    /// one small capsule beside Start, so the band stays a single doorway.
    private var alertButton: some View {
        GlassCapsuleButton(
            title: alertsDenied ? "Alerts off in Settings" : (alertsEnabled ? "Alerts on" : "Alerts off"),
            systemImage: alertsEnabled ? "bell.fill" : "bell.slash"
        ) {
            if alertsDenied {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                return
            }
            if alertsEnabled {
                alertsEnabled = false
                return
            }
            Task {
                let granted = await TimerAlertScheduler.requestPermission()
                alertsEnabled = granted
                alertsDenied = !granted
            }
        }
        .accessibilityHint("A notification when a round ends while Turn Timer isn't on screen")
        .task {
            // Reflect what iOS allows now, not what was true last time.
            if let authorized = await TimerAlertScheduler.isAuthorized() {
                alertsDenied = !authorized && alertsEnabled
                if !authorized { alertsEnabled = false }
            }
        }
    }

    private var startBar: some View {
        HStack(spacing: 10) {
            alertButton
            startButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            // A solid band with a hairline edge: rows scroll cleanly under it
            // and never look faded or disabled.
            Theme.ColorValue.appBackground
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.ColorValue.surfaceStroke).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var startButton: some View {
        GlassCapsuleButton(
            title: Theme.Label.start,
            systemImage: Theme.Symbol.play,
            prominent: true
        ) {
            editor.autoSave()
            onPlayGame(editor.buildGameSequence())
        }
        .disabled(!editor.canSaveOrStartTemplate)
        .accessibilityIdentifier("templates.start")
        .accessibilityLabel("Start \(editor.gameTitle)")
    }

    // MARK: - Helpers

    private func saveGame() {
        let result = editor.saveToDocuments(isProUnlocked: proAccess.isProUnlocked)
        switch result {
        case .saved:
            break
        case .requiresPro:
            requestedProFeature = .unlimitedTemplates
        case .failed(let errors):
            saveAlertMessage = errors.map(\.message).joined(separator: "\n")
            showSaveAlert = true
        }
    }

    private func loadSavedTemplate(_ template: SavedTemplate) {
        let result = editor.applySavedTemplate(template)
        guard !result.0 else { return }
        saveAlertMessage = result.1.map(\.message).joined(separator: "\n")
        showSaveAlert = true
    }

    private func exportCurrentTemplate() {
        guard let url = editor.exportCurrentTemplateURL() else {
            saveAlertMessage = "Template export failed."
            showSaveAlert = true
            return
        }
        shareItem = TemplateShareItem(url: url)
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            switch editor.importTemplate(from: url, isProUnlocked: proAccess.isProUnlocked) {
            case .imported(let template):
                saveAlertMessage = "Imported \(template.title)."
                showSaveAlert = true
            case .requiresPro:
                requestedProFeature = .unlimitedTemplates
            case .failed(let errors):
                saveAlertMessage = errors.map(\.message).joined(separator: "\n")
                showSaveAlert = true
            }
        case .failure(let error):
            saveAlertMessage = "Import failed: \(error.localizedDescription)"
            showSaveAlert = true
        }
    }
}

private struct TemplateShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Player Edit Sheet

private struct PlayerEditSheet: View {
    let round: Round
    let onUpdateName: (String) -> Void
    let onUpdateColor: (RoundColor) -> Void
    let onUpdateSound: (TimerSound) -> Void
    let onPreviewSound: (TimerSound) -> Void
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
    @FocusState private var emojiFocused: Bool

    init(
        round: Round,
        onUpdateName: @escaping (String) -> Void,
        onUpdateColor: @escaping (RoundColor) -> Void,
        onUpdateSound: @escaping (TimerSound) -> Void,
        onPreviewSound: @escaping (TimerSound) -> Void,
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
        self.onPreviewSound = onPreviewSound
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

    private var selectedColor: Color {
        RoundColor.palette(index: selectedColorIndex).swiftUIColor
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    preview

                    groupHeader("Round")

                    field("Name") {
                        TextField("Round name", text: $nameText)
                            .font(.body.weight(.medium))
                            .padding(12)
                            .background(Theme.ColorValue.surface, in: .rect(cornerRadius: 12))
                            .onChange(of: nameText) { _, newValue in
                                onUpdateName(newValue)
                            }
                    }

                    field("Time") {
                        GlassStepper(
                            value: durationDisplay,
                            decrementLabel: "Shorter",
                            incrementLabel: "Longer",
                            canDecrement: localDuration > Theme.TimerMechanic.minimumDuration,
                            onDecrement: { setDuration(localDuration - Theme.TimerMechanic.durationStep) },
                            onIncrement: { setDuration(localDuration + Theme.TimerMechanic.durationStep) }
                        )
                        .accessibilityLabel("Time, \(durationDisplay)")
                    }

                    groupHeader("Look")

                    field("Colour") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Editor.colorSwatchSpacing), count: 8), spacing: Theme.Editor.colorSwatchSpacing) {
                            ForEach(0..<Theme.ColorValue.timerPalette.count, id: \.self) { index in
                                Button {
                                    selectedColorIndex = index
                                    onUpdateColor(.palette(index: index))
                                } label: {
                                    Circle()
                                        .fill(Theme.ColorValue.timerPalette[index])
                                        .frame(width: Theme.Editor.colorSwatchSize, height: Theme.Editor.colorSwatchSize)
                                        .padding(3)
                                        .overlay {
                                            if selectedColorIndex == index {
                                                Circle().strokeBorder(.white, lineWidth: 2.5)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(RoundColor.paletteNames[index]) colour")
                                .accessibilityAddTraits(selectedColorIndex == index ? .isSelected : [])
                            }
                        }
                    }

                    field("Emoji") {
                        HStack(spacing: 12) {
                            TextField("＋", text: $emojiText)
                                .font(.system(size: 30))
                                .multilineTextAlignment(.center)
                                .frame(width: 60, height: 60)
                                .background(Theme.ColorValue.surface, in: .rect(cornerRadius: 16))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(selectedColor.opacity(0.8), lineWidth: 1.5)
                                }
                                .focused($emojiFocused)
                                .onChange(of: emojiText) { _, newValue in
                                    onUpdateEmoji(newValue)
                                }
                                .accessibilityLabel("Emoji")
                            Text("Tap the tile, or the dial above, to change it.")
                                .font(.caption)
                                .foregroundStyle(Theme.ColorValue.textSecondary)
                        }
                    }

                    groupHeader("Behaviour")

                    field("End sound") {
                        Picker("End sound", selection: $selectedSound) {
                            ForEach(TimerSound.allCases, id: \.self) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedSound) { _, newValue in
                            onUpdateSound(newValue)
                            onPreviewSound(newValue)
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        toggle(
                            "Counts as a turn",
                            hint: "On for players. Off for breaks and steps, which don't count in “Turn 2 of 3”.",
                            symbol: "person.fill",
                            isOn: $countsAsPlayer
                        )
                        .onChange(of: countsAsPlayer) { _, newValue in
                            onUpdateCountsAsPlayer(newValue)
                        }

                        toggle(
                            Theme.Label.startPaused,
                            hint: "Waits for a tap on the dial before this round counts down.",
                            symbol: Theme.Symbol.startPaused,
                            isOn: $startPaused
                        )
                        .onChange(of: startPaused) {
                            onToggleStartPaused()
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.ColorValue.appBackground)
            .navigationTitle("Edit round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Theme.Label.done) { onDismiss() }
                        .font(.body.weight(.semibold))
                }
            }
        }
        .presentationBackground(Theme.ColorValue.appBackground)
    }

    /// The round as it will look on the dial, updated with every change.
    private var preview: some View {
        Button {
            emojiFocused = true
        } label: {
            ZStack {
                SequencePie(segments: [SequenceSegment(id: 0, color: selectedColor, seconds: 1)], glowColor: selectedColor)
                if !emojiText.isEmpty {
                    Text(emojiText).font(.system(size: 34))
                        .shadow(color: .black.opacity(Theme.TimerStyle.shadeOpacity), radius: 3)
                }
            }
            .frame(width: 104, height: 104)
            .animation(.easeInOut(duration: Theme.TimerStyle.colourDuration), value: selectedColorIndex)
        }
        .buttonStyle(TimerPressStyle())
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
        .accessibilityLabel("Round preview. Tap to change the emoji.")
    }

    private func groupHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle().fill(Theme.ColorValue.surfaceStroke).frame(height: 1)
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.ColorValue.textTertiary)
        }
        .padding(.top, 6)
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ColorValue.textSecondary)
            content()
        }
    }

    private func toggle(_ title: String, hint: String, symbol: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Label(title, systemImage: symbol)
                    .font(.body.weight(.medium))
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
    }

    private func setDuration(_ seconds: Int) {
        localDuration = max(Theme.TimerMechanic.minimumDuration, seconds)
        onUpdateDuration(localDuration)
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

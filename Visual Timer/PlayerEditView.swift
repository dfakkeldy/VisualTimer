import SwiftUI

/// Expanded inline editor for a single round.
struct PlayerEditView: View {

    let round: Round
    let onUpdateName: (String) -> Void
    let onUpdateColor: (RoundColor) -> Void
    let onUpdateSound: (TimerSound) -> Void
    let onUpdateEmoji: (String) -> Void
    let onUpdateDuration: (Int) -> Void
    let onToggleStartPaused: () -> Void
    let onDismiss: () -> Void

    @State private var nameText: String
    @State private var emojiText: String
    @State private var selectedSound: TimerSound
    @State private var startPaused: Bool
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
        onDismiss: @escaping () -> Void
    ) {
        self.round = round
        self.onUpdateName = onUpdateName
        self.onUpdateColor = onUpdateColor
        self.onUpdateSound = onUpdateSound
        self.onUpdateEmoji = onUpdateEmoji
        self.onUpdateDuration = onUpdateDuration
        self.onToggleStartPaused = onToggleStartPaused
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
    }

    var body: some View {
        VStack(spacing: 16) {
            // Name field
            HStack {
                Text("Name")
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                TextField("Round name", text: $nameText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: nameText) { _, newValue in
                        onUpdateName(newValue)
                    }
            }

            // Color picker — grid of palette swatches
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Editor.colorSwatchSpacing), count: 8), spacing: Theme.Editor.colorSwatchSpacing) {
                    ForEach(0..<Theme.ColorValue.timerPalette.count, id: \.self) { index in
                        let color = Theme.ColorValue.timerPalette[index]
                        Button {
                            selectedColorIndex = index
                            onUpdateColor(.palette(index: index))
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: Theme.Editor.colorSwatchSize, height: Theme.Editor.colorSwatchSize)
                                .overlay {
                                    if selectedColorIndex == index {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(RoundColor.paletteNames[index]) color")
                        .accessibilityValue(selectedColorIndex == index ? "Selected" : "Not selected")
                    }
                }
            }

            // Sound picker
            HStack {
                Text("Sound")
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
            HStack {
                Text("Emoji")
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                TextField("🎮", text: $emojiText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: Theme.Editor.emojiFieldWidth)
                    .onChange(of: emojiText) { _, newValue in
                        onUpdateEmoji(newValue)
                    }
            }

            // Duration stepper
            HStack {
                Text("Time")
                    .foregroundStyle(Theme.ColorValue.textSecondary)

                Button {
                    let newDuration = max(Theme.TimerMechanic.minimumDuration,
                        localDuration - Theme.TimerMechanic.durationStep)
                    localDuration = newDuration
                    onUpdateDuration(newDuration)
                } label: {
                    Image(systemName: Theme.Symbol.decrement)
                }

                Text(durationDisplay)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ColorValue.textPrimary)

                Button {
                    let newDuration = localDuration + Theme.TimerMechanic.durationStep
                    localDuration = newDuration
                    onUpdateDuration(newDuration)
                } label: {
                    Image(systemName: Theme.Symbol.increment)
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

            // Dismiss button
            Button("Done") { onDismiss() }
                .font(.body.weight(.medium))
        }
        .padding(.vertical, 12)
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

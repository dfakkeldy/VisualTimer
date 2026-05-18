import SwiftUI

/// Expanded inline editor for a single round.
struct PlayerEditView: View {

    @Binding var round: Round
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Name field
            HStack {
                Text("Name")
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                TextField("Round name", text: $round.name)
                    .textFieldStyle(.roundedBorder)
            }

            // Color picker — grid of palette swatches
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Editor.colorSwatchSpacing), count: 8), spacing: Theme.Editor.colorSwatchSpacing) {
                    ForEach(0..<Theme.ColorValue.timerPalette.count, id: \.self) { index in
                        let color = Theme.ColorValue.timerPalette[index]
                        Button {
                            round.color = .palette(index: index)
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: Theme.Editor.colorSwatchSize, height: Theme.Editor.colorSwatchSize)
                                .overlay {
                                    if case .palette(let i) = round.color, i == index {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 2)
                                    }
                                }
                        }
                    }
                }
            }

            // Sound picker
            HStack {
                Text("Sound")
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                Picker("Sound", selection: $round.sound) {
                    ForEach(TimerSound.allCases, id: \.self) { sound in
                        Text(sound.displayName).tag(sound)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Emoji field
            HStack {
                Text("Emoji")
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                TextField("🎮", text: $round.emoji)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: Theme.Editor.emojiFieldWidth)
            }

            // Duration stepper
            HStack {
                Text("Time")
                    .foregroundStyle(Theme.ColorValue.textSecondary)

                Button {
                    round.durationSeconds = max(Theme.TimerMechanic.minimumDuration,
                        round.durationSeconds - Theme.TimerMechanic.durationStep)
                } label: {
                    Image(systemName: Theme.Symbol.decrement)
                }

                Text(round.durationDisplay)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ColorValue.textPrimary)

                Button {
                    round.durationSeconds += Theme.TimerMechanic.durationStep
                } label: {
                    Image(systemName: Theme.Symbol.increment)
                }
            }

            // Start paused toggle
            Toggle(isOn: $round.startPaused) {
                Label(Theme.Label.startPaused, systemImage: Theme.Symbol.startPaused)
            }
            .toggleStyle(.switch)

            // Dismiss button
            Button("Done") { onDismiss() }
                .font(.body.weight(.medium))
        }
        .padding(.vertical, 12)
    }
}

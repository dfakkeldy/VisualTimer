import SwiftUI

/// A sheet that lets the user pick one of three finish sounds.
/// The selection is persisted via `@AppStorage` inside `SoundManager`.
struct SettingsView: View {

    @ObservedObject var soundManager: SoundManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(TimerSound.allCases, id: \.self) { sound in
                        Button {
                            soundManager.selectedSound = sound
                        } label: {
                            HStack {
                                Text(sound.displayName)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if soundManager.selectedSound == sound {
                                    Image(systemName: Theme.Symbol.checkmark)
                                        .foregroundStyle(Theme.ColorValue.selectionAccent)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Timer End Sound")
                } footer: {
                    Text("This sound will play when the timer reaches zero.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

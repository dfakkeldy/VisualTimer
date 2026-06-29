import SwiftUI

/// A sheet that lets the user pick one of three finish sounds.
/// The selection is persisted via `@AppStorage` inside `SoundManager`.
struct SettingsView: View {

    @ObservedObject var soundManager: SoundManager
    @ObservedObject var proAccess: ProAccessViewModel
    @ObservedObject var templateSync: TemplateCloudSyncEngine
    @ObservedObject var historySync: HistoryCloudSyncEngine
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

                Section {
                    HStack {
                        Text("Template Sync")
                        Spacer()
                        Text(templateSync.statusText)
                            .foregroundStyle(Theme.ColorValue.textSecondary)
                    }

                    Button {
                        Task {
                            await templateSync.refreshNow()
                        }
                    } label: {
                        Text("Refresh Template Sync")
                    }
                    .disabled(!proAccess.isProUnlocked)

                    HStack {
                        Text("History Sync")
                        Spacer()
                        Text(historySync.statusText)
                            .foregroundStyle(Theme.ColorValue.textSecondary)
                    }

                    Button {
                        Task {
                            await historySync.refreshNow()
                        }
                    } label: {
                        Text("Refresh History Sync")
                    }
                    .disabled(!proAccess.isProUnlocked)

                    HStack {
                        Text("Status")
                        Spacer()
                        Text(proAccess.isProUnlocked ? "Unlocked" : "Free")
                            .foregroundStyle(Theme.ColorValue.textSecondary)
                    }

                    if !proAccess.isProUnlocked {
                        Button {
                            Task { await proAccess.purchasePro() }
                        } label: {
                            Text("Unlock Pro \(proAccess.displayPrice)")
                        }
                        .disabled(proAccess.purchaseState == .purchasing)
                    }

                    Button {
                        Task { await proAccess.restorePurchases() }
                    } label: {
                        Text("Restore Purchases")
                    }
                    .disabled(proAccess.purchaseState == .loading || proAccess.purchaseState == .purchasing)

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(Theme.ColorValue.textSecondary)
                    }
                } header: {
                    Text("Turn Timer Pro")
                } footer: {
                    Text("Pro unlocks unlimited templates, full history export, iCloud template sync, sharing, and widgets.")
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

    private var statusMessage: String? {
        switch proAccess.purchaseState {
        case .idle, .purchased:
            return nil
        case .loading:
            return "Checking purchase status..."
        case .purchasing:
            return "Purchasing..."
        case .pending:
            return "Purchase pending approval."
        case .failed(let message):
            return message
        }
    }
}

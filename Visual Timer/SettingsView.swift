import SwiftUI

/// Settings: the end sound, Turn Timer Pro, and iCloud sync once it applies.
struct SettingsView: View {

    @ObservedObject var soundManager: SoundManager
    @ObservedObject var proAccess: ProAccessViewModel
    @ObservedObject var templateSync: TemplateCloudSyncEngine
    @ObservedObject var historySync: HistoryCloudSyncEngine
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TimerAlertScheduler.enabledKey) private var alertsEnabled = false
    @State private var alertsDenied = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(TimerSound.allCases, id: \.self) { sound in
                        Button {
                            soundManager.selectedSound = sound
                            soundManager.playPreview(sound)
                        } label: {
                            HStack {
                                Text(sound.displayName)
                                    .foregroundStyle(Theme.ColorValue.textPrimary)
                                Spacer()
                                if soundManager.selectedSound == sound {
                                    Image(systemName: Theme.Symbol.checkmark)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Theme.ColorValue.selectionAccent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityAddTraits(soundManager.selectedSound == sound ? .isSelected : [])
                        .accessibilityHint("Plays a preview")
                        .listRowBackground(Theme.ColorValue.surface)
                    }
                } header: {
                    header("End sound")
                } footer: {
                    Text("Plays when a timer reaches zero. Tap one to hear it.")
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { alertsEnabled },
                        set: { newValue in
                            guard newValue else {
                                alertsEnabled = false
                                return
                            }
                            Task {
                                let granted = await TimerAlertScheduler.requestPermission()
                                alertsEnabled = granted
                                alertsDenied = !granted
                            }
                        }
                    )) {
                        Text("Alert me when time's up")
                    }
                    .listRowBackground(Theme.ColorValue.surface)
                } header: {
                    header("Alerts")
                } footer: {
                    Text(alertsDenied
                         ? "Notifications are off for Turn Timer. You can turn them on in the Settings app."
                         : "A notification when a timer or round ends while Turn Timer isn't on screen.")
                }

                Section {
                    if proAccess.isProUnlocked {
                        Label("Pro is unlocked", systemImage: Theme.Symbol.checkmark)
                            .listRowBackground(Theme.ColorValue.surface)
                    }

                    if !proAccess.isProUnlocked {
                        if proAccess.product == nil && proAccess.purchaseState != .loading {
                            Button("Retry loading Pro") {
                                Task { await proAccess.loadProducts() }
                            }
                            .listRowBackground(Theme.ColorValue.surface)
                        } else {
                            Button {
                                Task { await proAccess.purchasePro() }
                            } label: {
                                Label(proAccess.purchaseButtonTitle, systemImage: Theme.Symbol.proUnlock)
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 30)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!proAccess.canPurchase)
                            .listRowBackground(Theme.ColorValue.surface)
                        }
                    }

                    Button("Restore purchases") {
                        Task { await proAccess.restorePurchases() }
                    }
                    .disabled(proAccess.purchaseState == .loading || proAccess.purchaseState == .purchasing)
                    .listRowBackground(Theme.ColorValue.surface)

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(Theme.ColorValue.textSecondary)
                            .listRowBackground(Theme.ColorValue.surface)
                    }
                } header: {
                    header("Turn Timer Pro")
                } footer: {
                    Text("One-time purchase: more saved templates, full history and export, iCloud sync, sharing and widgets.")
                }

                Section {
                    syncRow("Templates", status: templateSync.statusText) {
                        await templateSync.refreshNow()
                    }
                    syncRow("History", status: historySync.statusText) {
                        await historySync.refreshNow()
                    }
                } header: {
                    header("iCloud sync")
                } footer: {
                    if !proAccess.isProUnlocked {
                        Text("Sync keeps templates and history on all your devices. It comes with Pro.")
                    }
                }

                Section {
                    Link("Privacy policy", destination: URL(string: "https://dfakkeldy.github.io/VisualTimer/privacy.html")!)
                        .accessibilityIdentifier("settings.privacy-policy")
                        .listRowBackground(Theme.ColorValue.surface)
                } header: {
                    header("Privacy")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.ColorValue.appBackground)
            .navigationTitle(Theme.Label.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Theme.Label.done) { dismiss() }
                        .font(.body.weight(.semibold))
                }
            }
        }
        .presentationBackground(Theme.ColorValue.appBackground)
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.ColorValue.textSecondary)
            .textCase(nil)
    }

    /// A sync status line. With Pro it refreshes on tap; without, it reads
    /// "With Pro" rather than offering a control that can't act.
    @ViewBuilder
    private func syncRow(_ title: String, status: String, refresh: @escaping () async -> Void) -> some View {
        if proAccess.isProUnlocked {
            Button {
                Task { await refresh() }
            } label: {
                HStack {
                    Text(title).foregroundStyle(Theme.ColorValue.textPrimary)
                    Spacer()
                    Text(status).foregroundStyle(Theme.ColorValue.textSecondary)
                    Image(systemName: Theme.Symbol.restart)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.ColorValue.selectionAccent)
                }
            }
            .accessibilityHint("Syncs now")
            .listRowBackground(Theme.ColorValue.surface)
        } else {
            HStack {
                Text(title)
                Spacer()
                Text("With Pro")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }
            .listRowBackground(Theme.ColorValue.surface)
        }
    }

    private var statusMessage: String? {
        switch proAccess.purchaseState {
        case .idle, .purchased:
            return nil
        case .loading:
            return "Checking purchase status…"
        case .purchasing:
            return "Purchasing…"
        case .pending:
            return "Purchase pending approval."
        case .failed(let message):
            return message
        }
    }
}

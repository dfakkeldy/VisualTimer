import SwiftUI

struct ProPaywallView: View {
    let feature: ProFeature
    @ObservedObject var proAccess: ProAccessViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(feature.title)
                        .font(.title2.bold())
                        .foregroundStyle(Theme.ColorValue.textPrimary)
                    Text(feature.message)
                        .font(.body)
                        .foregroundStyle(Theme.ColorValue.textSecondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Unlimited saved templates", systemImage: Theme.Symbol.proTemplates)
                    Label("Full history and export", systemImage: Theme.Symbol.proHistoryExport)
                    Label("iCloud sync, sharing, and widgets", systemImage: Theme.Symbol.proFutureFeatures)
                }
                .foregroundStyle(Theme.ColorValue.textPrimary)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.ColorValue.textSecondary)
                }

                Spacer()

                Button {
                    Task { await proAccess.purchasePro() }
                } label: {
                    Label("Unlock Pro \(proAccess.displayPrice)", systemImage: Theme.Symbol.proUnlock)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(proAccess.purchaseState == .purchasing)

                Button {
                    Task { await proAccess.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(proAccess.purchaseState == .loading || proAccess.purchaseState == .purchasing)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Theme.ColorValue.appBackground)
            .navigationTitle("Turn Timer Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                }
            }
            .onChange(of: proAccess.isProUnlocked) { _, unlocked in
                if unlocked { dismiss() }
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

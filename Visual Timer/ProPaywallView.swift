import SwiftUI

/// Turn Timer Pro: why it opened, what Pro adds, and an honest one-time price.
struct ProPaywallView: View {
    let feature: ProFeature
    @ObservedObject var proAccess: ProAccessViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Turn Timer Pro")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(Theme.ColorValue.textPrimary)
                        Text(feature.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.ColorValue.textPrimary)
                        Text(feature.message)
                            .font(.body)
                            .foregroundStyle(Theme.ColorValue.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(feature.orderedBenefits, id: \.text) { benefit in
                            HStack(spacing: 14) {
                                Image(systemName: benefit.symbol)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.ColorValue.textSecondary)
                                    .frame(width: 28, alignment: .center)
                                    .accessibilityHidden(true)
                                Text(benefit.text)
                                    .font(.body)
                                    .foregroundStyle(Theme.ColorValue.textPrimary)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.ColorValue.surface, in: .rect(cornerRadius: 16))

                    Spacer(minLength: 8)

                    // The decision sits at the bottom, where a thumb rests.
                    purchaseControls
                }
                .padding(20)
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            }
            .background(Theme.ColorValue.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
            .onChange(of: proAccess.isProUnlocked) { _, unlocked in
                if unlocked { dismiss() }
            }
        }
        .presentationBackground(Theme.ColorValue.appBackground)
        // A sheet sized close to its content, so no empty band sits between
        // the benefits and the purchase.
        .presentationDetents([.fraction(0.86), .large])
        .presentationDragIndicator(.visible)
    }

    private var purchaseControls: some View {
        VStack(spacing: 12) {
            if proAccess.product == nil && proAccess.purchaseState != .loading {
                Button("Retry loading Pro") {
                    Task { await proAccess.loadProducts() }
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    Task { await proAccess.purchasePro() }
                } label: {
                    Label(proAccess.purchaseButtonTitle, systemImage: Theme.Symbol.proUnlock)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!proAccess.canPurchase)
            }

            Text("One-time purchase. No subscription.")
                .font(.footnote)
                .foregroundStyle(Theme.ColorValue.textSecondary)

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }

            Button("Restore purchases") {
                Task { await proAccess.restorePurchases() }
            }
            .font(.subheadline)
            .disabled(proAccess.purchaseState == .loading || proAccess.purchaseState == .purchasing)
        }
        .frame(maxWidth: .infinity)
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

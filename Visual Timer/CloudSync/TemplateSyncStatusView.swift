import SwiftUI

struct TemplateSyncStatusView: View {
    @ObservedObject var syncEngine: TemplateCloudSyncEngine
    let isProUnlocked: Bool

    var body: some View {
        if isProUnlocked {
            HStack(spacing: 8) {
                Image(systemName: syncEngine.statusSymbol)
                    .foregroundStyle(iconColor)
                Text(syncEngine.statusText)
                    .font(.caption)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                    .lineLimit(1)
                Spacer()
                Button {
                    Task {
                        await syncEngine.refreshNow()
                    }
                } label: {
                    Image(systemName: Theme.Symbol.restart)
                }
                .accessibilityLabel("Refresh sync")
            }
            .padding(.horizontal, Theme.Dimension.screenHorizontalPadding)
            .padding(.bottom, 4)
        }
    }

    private var iconColor: Color {
        switch syncEngine.syncState {
        case .failed:
            return .orange
        case .syncing, .checkingAccount:
            return Theme.ColorValue.selectionAccent
        case .idle:
            return .green
        case .disabled:
            return Theme.ColorValue.textSecondary
        }
    }
}

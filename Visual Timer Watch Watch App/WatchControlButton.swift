import SwiftUI

/// Large labelled Watch control: an icon above a short title, at least the
/// Theme minimum touch height, with an explicit accessibility label and
/// identifier so VoiceOver never reads the symbol name.
struct WatchControlButton: View {

    let title: String
    let systemImage: String
    let accessibilityID: String
    let isProminent: Bool
    var tint: Color? = nil
    /// Off when another control (the dial) already shows this symbol.
    var showsIcon: Bool = true
    let action: () -> Void

    var body: some View {
        if isProminent {
            button.buttonStyle(.borderedProminent).tint(tint)
        } else {
            button.buttonStyle(.bordered).tint(tint)
        }
    }

    private var button: some View {
        Button(action: action) {
            VStack(spacing: Theme.Watch.Dimension.controlIconSpacing) {
                if showsIcon {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.caption2.weight(.semibold))
                    // On tinted glass the label stays white, so it reads as live.
                    .foregroundStyle(isProminent || tint == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
                    .lineLimit(1)
                    .minimumScaleFactor(Theme.Watch.Dimension.captionMinimumScale)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Watch.Dimension.controlMinHeight)
        }
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityID)
    }
}

import SwiftUI

/// The circular countdown visual — a dark base circle overlaid with
/// a colored ring that depletes clockwise from 12 o'clock as time elapses.
///
/// A linear animation matched to the 1-second tick interval interpolates
/// the depletion smoothly across each second, so the ring sweeps
/// continuously instead of hopping one notch per tick.
struct TimerVisualView: View {

    /// 0.0 = full circle, 1.0 = fully depleted.
    let elapsedFraction: Double

    /// The color of the depleting fill ring.
    var fillColor: Color = .red

    var body: some View {
        Circle()
            .fill(Theme.ColorValue.circleBackground)
            .overlay {
                GeometryReader { geometry in
                    let radius = geometry.size.width / 2
                    Circle()
                        .trim(from: elapsedFraction, to: 1.0)
                        .stroke(fillColor, lineWidth: radius)
                        .padding(radius / 2)
                        .rotationEffect(.degrees(Theme.Rotation.trimOriginOffset))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, Theme.Dimension.circleHorizontalPadding)
            .animation(.linear(duration: 1.0), value: elapsedFraction)
    }
}

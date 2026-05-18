import SwiftUI

/// The circular countdown visual — a dark base circle overlaid with
/// a colored ring that depletes clockwise from 12 o'clock as time elapses.
///
/// A short animation smooths the 1-second discrete ticks without
/// introducing perceptible lag.
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
            .animation(.easeInOut(duration: 0.3), value: elapsedFraction)
    }
}

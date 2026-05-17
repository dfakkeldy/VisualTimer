import SwiftUI

/// The circular countdown visual — a dark base circle overlaid with
/// a red ring that depletes clockwise from 12 o'clock as time elapses.
struct TimerVisualView: View {

    /// 0.0 = full red circle, 1.0 = fully depleted.
    let elapsedFraction: Double

    /// Drives the animation so each tick interpolates smoothly.
    let animatingValue: Int

    var body: some View {
        Circle()
            .fill(Theme.ColorValue.circleBackground)
            .overlay {
                GeometryReader { geometry in
                    let radius = geometry.size.width / 2
                    Circle()
                        .trim(from: elapsedFraction, to: 1.0)
                        .stroke(
                            Theme.ColorValue.timerFill,
                            lineWidth: radius
                        )
                        .padding(radius / 2)
                        .rotationEffect(.degrees(Theme.Rotation.trimOriginOffset))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, Theme.Dimension.circleHorizontalPadding)
            .animation(
                .linear(duration: Theme.AnimationValue.timerTickDuration),
                value: animatingValue
            )
    }
}

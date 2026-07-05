import SwiftUI

/// The circular countdown visual — a dark base circle overlaid with
/// a colored ring that depletes clockwise from 12 o'clock as time elapses.
///
/// `TimelineView(.animation)` samples wall-clock progress for each frame,
/// so the pie sweeps continuously instead of hopping between whole-second
/// timer updates.
struct TimerVisualView: View {

    let visualProgress: TimerVisualProgress

    /// The color of the depleting fill ring.
    var fillColor: Color = .red

    var body: some View {
        TimelineView(.animation(paused: !visualProgress.isRunning)) { timeline in
            pie(elapsedFraction: visualProgress.elapsedFraction(at: timeline.date))
        }
    }

    private func pie(elapsedFraction: Double) -> some View {
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
    }
}

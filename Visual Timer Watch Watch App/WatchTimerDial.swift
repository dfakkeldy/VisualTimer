import SwiftUI

/// Countdown ring for Watch timer screens. The ring and the centre content
/// read the same Date from one timeline, so the digits and the fill always
/// agree, including straight after the app wakes.
struct WatchTimerDial<Content: View>: View {

    let progress: TimerVisualProgress
    let color: Color
    @ViewBuilder let content: (Date) -> Content

    var body: some View {
        TimelineView(.animation(paused: !progress.isRunning)) { timeline in
            ZStack {
                Circle()
                    .stroke(Theme.Watch.ColorValue.ringTrack, lineWidth: Theme.Watch.Dimension.dialLineWidth)
                Circle()
                    .trim(from: progress.elapsedFraction(at: timeline.date), to: 1.0)
                    .stroke(color, lineWidth: Theme.Watch.Dimension.dialLineWidth)
                    .rotationEffect(.degrees(Theme.Rotation.trimOriginOffset))
                content(timeline.date)
            }
            .padding(Theme.Watch.Dimension.dialLineWidth / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

import SwiftUI

/// Countdown dial for Watch timer screens: the same emptying pie as the
/// iPhone, sweeping clockwise from twelve, with its readout beneath. The pie
/// and the digits read the same Date from one timeline, so they always agree,
/// including straight after the app wakes.
struct WatchTimerDial<Content: View>: View {

    let progress: TimerVisualProgress
    let color: Color
    var dialSize: CGFloat = Theme.Watch.Dimension.quickDialMaxSize
    @ViewBuilder let content: (Date) -> Content

    var body: some View {
        TimelineView(.animation(paused: !progress.isRunning)) { timeline in
            VStack(spacing: Theme.Watch.Dimension.contentSpacing) {
                ZStack {
                    Circle()
                        .fill(Theme.Watch.ColorValue.ringTrack)
                    RemainingTimerWedge(elapsedFraction: progress.elapsedFraction(at: timeline.date))
                        .fill(color)
                    Circle()
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                }
                .frame(width: dialSize, height: dialSize)
                .accessibilityHidden(true)

                content(timeline.date)
            }
        }
    }
}

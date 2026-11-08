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
        // A pie that moves under a degree a second needs no 60 fps: eight
        // frames a second keeps it smooth and leaves the main thread (and
        // the battery) free.
        TimelineView(.animation(minimumInterval: 1.0 / 8, paused: !progress.isRunning)) { timeline in
            VStack(spacing: Theme.Watch.Dimension.contentSpacing) {
                ZStack {
                    Circle()
                        .fill(Theme.Watch.ColorValue.ringTrack)
                    RemainingTimerWedge(elapsedFraction: progress.elapsedFraction(at: timeline.date))
                        .fill(color)
                        .overlay {
                            // The phone dial's light, at wrist scale.
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.28), location: 0),
                                    .init(color: .clear, location: 0.5),
                                    .init(color: .black.opacity(0.2), location: 1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .mask(RemainingTimerWedge(elapsedFraction: progress.elapsedFraction(at: timeline.date)))
                        }
                    Circle()
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                }
                .shadow(color: color.opacity(0.35), radius: 8)
                .frame(width: dialSize, height: dialSize)
                .accessibilityHidden(true)

                content(timeline.date)
            }
        }
    }
}

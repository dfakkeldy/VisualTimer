import SwiftUI

/// Makes the dial itself a named control: its label shows in the dial's
/// centre, and VoiceOver and UI tests reach it as a button.
struct WatchDialButton {
    let title: String
    let symbol: String
    let accessibilityID: String
    let action: () -> Void
}

/// Countdown dial for Watch timer screens: the same emptying pie as the
/// iPhone, sweeping clockwise from twelve, with its readout beneath. The pie
/// and the digits read the same Date from one timeline, so they always agree,
/// including straight after the app wakes.
struct WatchTimerDial<Content: View>: View {

    let progress: TimerVisualProgress
    let color: Color
    var dialSize: CGFloat = Theme.Watch.Dimension.quickDialMaxSize
    /// The phone's model: a tap on the dial starts, pauses or resumes.
    /// VoiceOver and UI tests use a labelled button beside the dial.
    var centerSymbol: String? = nil
    var onTap: (() -> Void)? = nil
    /// Set this instead where no other control starts the timer.
    var button: WatchDialButton? = nil
    @ViewBuilder let content: (Date) -> Content

    var body: some View {
        // A pie that moves under a degree a second needs no 60 fps: eight
        // frames a second keeps it smooth and leaves the main thread (and
        // the battery) free.
        TimelineView(.animation(minimumInterval: 1.0 / 8, paused: !progress.isRunning)) { timeline in
            VStack(spacing: Theme.Watch.Dimension.contentSpacing) {
                if let button {
                    Button(action: button.action) {
                        dial(at: timeline.date)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(button.title)
                    .accessibilityIdentifier(button.accessibilityID)
                } else {
                    dial(at: timeline.date)
                        .onTapGesture { onTap?() }
                        .accessibilityHidden(true)
                }

                content(timeline.date)
            }
        }
    }

    private func dial(at date: Date) -> some View {
        ZStack {
            // The empty sector is the phone's ink, with a hairline rim.
            Circle()
                .fill(Theme.TimerStyle.ink)
            RemainingTimerWedge(elapsedFraction: progress.elapsedFraction(at: date))
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
                    .mask(RemainingTimerWedge(elapsedFraction: progress.elapsedFraction(at: date)))
                }
            Circle()
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
            center
        }
        .shadow(color: color.opacity(0.25), radius: 6)
        .frame(width: dialSize, height: dialSize)
        .contentShape(Circle())
    }

    @ViewBuilder
    private var center: some View {
        if let button {
            let disc = dialSize * Theme.Watch.Dimension.dialLabelledDiscRatio
            Circle()
                .fill(Theme.TimerStyle.ink)
                .frame(width: disc, height: disc)
            VStack(spacing: 0) {
                Image(systemName: button.symbol)
                    .font(.system(size: dialSize * 0.15, weight: .semibold))
                Text(button.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(Theme.Watch.Dimension.captionMinimumScale)
            }
            .foregroundStyle(.white)
            .frame(width: disc * 0.88)
        } else if let centerSymbol {
            Circle()
                .fill(Theme.TimerStyle.ink)
                .frame(width: dialSize * 0.42, height: dialSize * 0.42)
            Image(systemName: centerSymbol)
                .font(.system(size: dialSize * 0.18, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

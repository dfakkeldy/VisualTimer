import SwiftUI

/// A coloured glass dial whose remaining wedge sweeps clockwise from twelve.
/// The supplied colour remains the source of every tint; round colours and the
/// quick timer's palette retain their meaning. Only the mask and sweep edge update each frame.
struct TimerVisualView: View {
    let visualProgress: TimerVisualProgress
    var fillColor: Color = .red
    var completionCount: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var simplified: Bool { reduceTransparency || contrast == .increased }

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.TimerStyle.well)

            Circle()
                .fill(fillColor)
                .overlay {
                    if !simplified {
                        Circle()
                            .fill(surfaceLighting)
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            .white.opacity(Theme.TimerStyle.highlightOpacity),
                            lineWidth: Theme.TimerStyle.rimWidth
                        )
                }
                .mask {
                    TimelineView(.animation(paused: !visualProgress.isRunning)) { timeline in
                        RemainingTimerWedge(
                            elapsedFraction: visualProgress.elapsedFraction(at: timeline.date)
                        )
                    }
                }
                .overlay {
                    if !simplified {
                        TimelineView(.animation(paused: !visualProgress.isRunning)) { timeline in
                            RemainingTimerWedge(
                                elapsedFraction: visualProgress.elapsedFraction(at: timeline.date)
                            )
                            .stroke(surfaceLighting, lineWidth: Theme.TimerStyle.surfaceBorder)
                        }
                    }
                }
                .shadow(
                    color: simplified ? .clear : fillColor.opacity(Theme.TimerStyle.glowOpacity),
                    radius: Theme.TimerStyle.glowRadius
                )

            Circle()
                .strokeBorder(
                    .white.opacity(Theme.TimerStyle.backdropOpacity),
                    lineWidth: Theme.TimerStyle.surfaceBorder
                )

            if !reduceMotion && !simplified {
                completionRipple
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: Theme.TimerStyle.colourDuration),
            value: fillColor
        )
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, Theme.Dimension.circleHorizontalPadding)
        .accessibilityHidden(true)
    }

    private var surfaceLighting: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(Theme.TimerStyle.highlightOpacity), location: 0),
                .init(color: .clear, location: 0.45),
                .init(color: .black.opacity(Theme.TimerStyle.shadeOpacity), location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var completionRipple: some View {
        Circle()
            .strokeBorder(fillColor, lineWidth: Theme.TimerStyle.rimWidth)
            .keyframeAnimator(initialValue: Ripple(), trigger: completionCount) { content, value in
                content
                    .scaleEffect(value.scale)
                    .opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    LinearKeyframe(1, duration: 0)
                    CubicKeyframe(Theme.TimerStyle.rippleScale, duration: Theme.TimerStyle.rippleDuration)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(Theme.TimerStyle.rippleOpacity, duration: Theme.TimerStyle.rippleAttack)
                    LinearKeyframe(0, duration: Theme.TimerStyle.rippleDuration - Theme.TimerStyle.rippleAttack)
                }
            }
            .allowsHitTesting(false)
    }

    private struct Ripple {
        var scale: CGFloat = 1
        var opacity: Double = 0
    }
}

/// Deliberately has no interpolated animatable data: wall-clock samples describe
/// the exact wedge, including pause/resume and a newly replenished round.
struct RemainingTimerWedge: Shape {
    let elapsedFraction: Double

    func path(in rect: CGRect) -> Path {
        let fraction = min(max(elapsedFraction, 0), 1)
        guard fraction < 1 else { return Path() }
        if fraction == 0 { return Path(ellipseIn: rect) }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: min(rect.width, rect.height) / 2,
            startAngle: .degrees(Theme.Rotation.trimOriginOffset + fraction * 360),
            endAngle: .degrees(Theme.Rotation.trimOriginOffset + 360),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

#Preview("Coloured glass · partial countdown") {
    let start = Date()
    let progress = TimerVisualProgress(totalDuration: 25)
        .running(from: start)
        .paused(at: start.addingTimeInterval(7))
    VStack {
        TimerVisualView(visualProgress: progress, fillColor: .teal)
        TimerVisualView(visualProgress: progress, fillColor: .orange)
    }
    .padding()
    .background(Theme.TimerStyle.ink)
}

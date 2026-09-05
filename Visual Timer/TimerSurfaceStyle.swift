import SwiftUI

/// Glass is confined to controls. Older systems retain a material surface,
/// while accessibility settings use an opaque, outlined control.
private struct TimerControlSurface<S: Shape>: ViewModifier {
    let shape: S
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content
                .background(Theme.ColorValue.buttonFill, in: shape)
                .overlay {
                    shape.stroke(.white.opacity(Theme.TimerStyle.highlightOpacity), lineWidth: Theme.TimerStyle.surfaceBorder)
                        .allowsHitTesting(false)
                }
        } else if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(.white.opacity(Theme.TimerStyle.backdropOpacity), lineWidth: Theme.TimerStyle.surfaceBorder)
                        .allowsHitTesting(false)
                }
        }
    }
}

extension View {
    func timerControlSurface(in shape: some Shape) -> some View {
        modifier(TimerControlSurface(shape: shape))
    }
}

struct TimerGlassGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: Theme.TimerStyle.controlSpacing, content: content)
        } else {
            content()
        }
    }
}

struct TimerPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? Theme.TimerStyle.pressedScale : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: Theme.TimerStyle.pressDuration),
                value: configuration.isPressed
            )
    }
}

struct TimerBackdrop: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Theme.TimerStyle.ink
            .overlay {
                if !reduceTransparency && contrast != .increased {
                    RadialGradient(
                        colors: [color.opacity(Theme.TimerStyle.backdropOpacity), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: Theme.Dimension.compactTimerCircleMaxSize
                    )
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: Theme.TimerStyle.colourDuration), value: color)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

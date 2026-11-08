import SwiftUI

// Shared controls and marks for the iPhone app, so every screen uses one
// material: glass chips and capsules on the ink canvas, and round colours as
// the app's signature.

// MARK: - Glass controls

/// A round glass control holding one symbol, with a spoken label.
struct GlassIconButton: View {
    let systemImage: String
    let label: String
    var size: CGFloat = Theme.TimerStyle.controlSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.ColorValue.textPrimary)
                .frame(width: size, height: size)
                .timerControlSurface(in: Circle())
        }
        .buttonStyle(TimerPressStyle())
        .accessibilityLabel(label)
    }
}

/// A labelled glass capsule. `prominent` fills it with `tint` for the one main action.
struct GlassCapsuleButton: View {
    let title: String
    let systemImage: String?
    var prominent: Bool = false
    var tint: Color = Theme.ColorValue.selectionAccent
    /// Share a row's width equally with its neighbours.
    var fillsWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(Theme.ColorValue.textPrimary)
            .padding(.horizontal, Theme.TimerStyle.capsuleHorizontalPadding)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: Theme.TimerStyle.capsuleHeight)
            .background {
                if prominent {
                    Capsule().fill(tint)
                }
            }
            .modifier(CapsuleSurface(prominent: prominent))
        }
        .buttonStyle(TimerPressStyle())
    }
}

private struct CapsuleSurface: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if prominent {
            content.environment(\.colorScheme, .dark)
        } else {
            content.timerControlSurface(in: Capsule())
        }
    }
}

/// − value + on glass, the one stepper used across the app.
struct GlassStepper: View {
    let value: String
    let decrementLabel: String
    let incrementLabel: String
    var canDecrement: Bool = true
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        TimerGlassGroup {
            HStack(spacing: Theme.TimerStyle.controlSpacing) {
                GlassIconButton(systemImage: Theme.Symbol.decrease, label: decrementLabel, size: 36, action: onDecrement)
                    .disabled(!canDecrement)
                Text(value)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.ColorValue.textPrimary)
                    .frame(minWidth: 64)
                    .accessibilityHidden(true)
                GlassIconButton(systemImage: Theme.Symbol.increase, label: incrementLabel, size: 36, action: onIncrement)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Glyph disc

/// A small ink disc behind the dial's centre glyph, so the glyph stays one
/// colour wherever the pie edge crosses it.
struct GlyphDisc<Content: View>: View {
    var size: CGFloat = Theme.TimerStyle.glyphDiscSize
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.TimerStyle.ink)
                .overlay {
                    Circle().strokeBorder(.white.opacity(Theme.TimerStyle.backdropOpacity), lineWidth: Theme.TimerStyle.surfaceBorder)
                }
                .frame(width: size, height: size)
            content()
        }
    }
}

// MARK: - Round colour marks

/// One coloured segment per round, sized by its duration.
struct SequenceSegment: Identifiable, Equatable {
    let id: Int
    let color: Color
    let seconds: Int
}

extension GameSequence {
    var segments: [SequenceSegment] {
        activeRounds.enumerated().map { index, round in
            SequenceSegment(id: index, color: round.color.swiftUIColor, seconds: round.durationSeconds)
        }
    }

    /// Total running time, counting every repeat.
    var totalSeconds: Int {
        activeRounds.reduce(0) { $0 + $1.durationSeconds } * max(roundCount, 1)
    }
}

/// A thin bar of round colours, each as long as its round. Shows a sequence's
/// shape and length at a glance.
struct SequenceRibbon: View {
    let segments: [SequenceSegment]
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            let gap: CGFloat = segments.count > 1 ? 2 : 0
            let total = max(segments.reduce(0) { $0 + $1.seconds }, 1)
            let usable = max(proxy.size.width - gap * CGFloat(segments.count - 1), 0)
            HStack(spacing: gap) {
                ForEach(segments) { segment in
                    Capsule()
                        .fill(segment.color)
                        .frame(width: max(usable * CGFloat(segment.seconds) / CGFloat(total), 2))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// A full dial cut into round-coloured wedges, sized by duration: the whole
/// session as one picture, with the live dial's light, rim and glow.
struct SequencePie: View {
    let segments: [SequenceSegment]
    var glowColor: Color? = nil

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        wedges
            .overlay {
                if !reduceTransparency {
                    Circle().fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(Theme.TimerStyle.highlightOpacity), location: 0),
                                .init(color: .clear, location: 0.45),
                                .init(color: .black.opacity(Theme.TimerStyle.shadeOpacity), location: 1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .overlay {
                Circle().strokeBorder(.white.opacity(Theme.TimerStyle.highlightOpacity), lineWidth: Theme.TimerStyle.rimWidth)
            }
            .background {
                if let glowColor, !reduceTransparency {
                    Circle()
                        .fill(Theme.TimerStyle.well)
                        .shadow(color: glowColor.opacity(Theme.TimerStyle.glowOpacity), radius: Theme.TimerStyle.glowRadius)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }

    private var wedges: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(size.width, size.height) / 2
            let total = Double(max(segments.reduce(0) { $0 + $1.seconds }, 1))
            var start = Theme.Rotation.trimOriginOffset
            for segment in segments {
                let sweep = Double(segment.seconds) / total * 360
                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(start + sweep), clockwise: false)
                path.closeSubpath()
                context.fill(path, with: .color(segment.color))
                if segments.count > 1 {
                    context.stroke(path, with: .color(Theme.TimerStyle.ink.opacity(0.7)), lineWidth: 0.75)
                }
                start += sweep
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Time text

enum TimerText {
    /// "05:00" style for countdown digits.
    static func clock(_ seconds: Int) -> String {
        let s = max(seconds, 0)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    /// "9:01" style for lengths.
    static func length(_ seconds: Int) -> String {
        let s = max(seconds, 0)
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// "32 min" or "45 sec": a length in plain words.
    static func words(_ seconds: Int) -> String {
        let s = max(seconds, 0)
        if s < 60 { return "\(s) sec" }
        let minutes = Int((Double(s) / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) hr" : "\(hours) hr \(rest) min"
    }

    /// "about 18 min left", for whole-session estimates.
    static func approximateLeft(_ seconds: Int) -> String {
        seconds < 60 ? "under a minute left" : "about \(words(seconds)) left"
    }

    /// "18 min left", the short form for a running caption.
    static func left(_ seconds: Int) -> String {
        seconds < 60 ? "under a minute left" : "\(words(seconds)) left"
    }

    /// "Ends 9:46", a clock time `seconds` from `now`.
    static func endsAt(_ seconds: Int, from now: Date = Date()) -> String {
        let end = now.addingTimeInterval(TimeInterval(seconds))
        return "Ends \(end.formatted(date: .omitted, time: .shortened))"
    }
}

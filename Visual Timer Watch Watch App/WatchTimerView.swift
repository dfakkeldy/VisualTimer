import SwiftUI

/// Watch Quick Timer. While idle, tap minutes or seconds and turn the
/// Digital Crown to edit; once started, the digits show the live remaining
/// time. State lives in `WatchAppModel`, so leaving this screen neither stops
/// nor resets the countdown.
struct WatchTimerView: View {

    @ObservedObject var viewModel: WatchQuickTimerViewModel

    var body: some View {
        GeometryReader { proxy in
            content(dialSize: dialSize(forHeight: proxy.size.height))
                .frame(width: proxy.size.width)
        }
        .focusable(true)
        .digitalCrownRotation(
            $viewModel.crownValue,
            from: Double(WatchQuickTimerViewModel.componentRange.lowerBound),
            through: Double(WatchQuickTimerViewModel.componentRange.upperBound),
            by: 1,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: viewModel.selectedComponent != nil
        )
    }

    /// Leaves room for the readout row and the crown cue, so the dial keeps
    /// one size in every state on every Watch.
    private func dialSize(forHeight height: CGFloat) -> CGFloat {
        let dimension = Theme.Watch.Dimension.self
        return min(dimension.quickPieSize, max(dimension.quickPieMinSize, height - dimension.quickBelowDialHeight))
    }

    private func content(dialSize: CGFloat) -> some View {
        VStack(spacing: Theme.Watch.Dimension.contentSpacing) {
            WatchTimerDial(
                progress: viewModel.timer.visualProgress,
                color: viewModel.timer.timerColor,
                dialSize: dialSize,
                button: viewModel.primaryControl.map { primary in
                    WatchDialButton(
                        title: primary.title,
                        symbol: primary.symbol,
                        accessibilityID: Theme.Watch.Identifier.quickPrimary,
                        action: { viewModel.performPrimaryAction() }
                    )
                }
            ) { date in
                if viewModel.canEditDuration {
                    VStack(spacing: 0) {
                        durationEditor
                        // The cue teaches once; it goes once a number is chosen.
                        if viewModel.selectedComponent == nil {
                            Text(Theme.Watch.Label.crownCue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(Theme.Watch.Dimension.captionMinimumScale)
                            .accessibilityHidden(true)
                        }
                    }
                } else {
                    // One row for the digits and Reset: the digits stay centred
                    // and the dial keeps its size when Reset appears.
                    remainingTime(at: date)
                        .frame(maxWidth: .infinity, minHeight: Theme.Watch.Dimension.controlMinHeight)
                        .overlay(alignment: .trailing) {
                            if viewModel.showsReset {
                                resetButton
                            }
                        }
                }
            }
            // The timeline would otherwise take spare height and re-centre
            // the dial inside it.
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var resetButton: some View {
        Button {
            viewModel.reset()
        } label: {
            Image(systemName: Theme.Symbol.reset)
                .font(.body.weight(.semibold))
                .frame(
                    width: Theme.Watch.Dimension.controlMinHeight,
                    height: Theme.Watch.Dimension.controlMinHeight
                )
                .background(Circle().fill(Theme.Watch.ColorValue.editable))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Theme.Label.reset)
        .accessibilityIdentifier(Theme.Watch.Identifier.quickReset)
    }

    // MARK: - Digits

    private func remainingTime(at date: Date) -> some View {
        let seconds = viewModel.displayedSeconds(at: date)
        return Text(WatchTimeText.clock(seconds))
            .font(.system(.title2, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(Theme.Watch.Dimension.digitMinimumScale)
            .accessibilityLabel(Theme.Watch.Label.timeRemaining)
            .accessibilityValue(WatchTimeText.spoken(seconds))
            .accessibilityIdentifier(Theme.Watch.Identifier.quickTime)
    }

    private var durationEditor: some View {
        HStack(spacing: 0) {
            componentButton(.minutes, label: Theme.Watch.Label.minutes, id: Theme.Watch.Identifier.quickMinutes)
            Text(Theme.Watch.Label.timeSeparator)
                .accessibilityHidden(true)
            componentButton(.seconds, label: Theme.Watch.Label.seconds, id: Theme.Watch.Identifier.quickSeconds)
        }
        .font(.system(.title2, design: .rounded).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(Theme.Watch.Dimension.digitMinimumScale)
        .padding(.horizontal, 4)
        // One well for the one readout; the selected number lights up inside it.
        .background(
            RoundedRectangle(cornerRadius: Theme.Watch.Dimension.selectionCornerRadius)
                .fill(Theme.Watch.ColorValue.editable)
        )
    }

    private func componentButton(_ component: WatchTimeComponent, label: String, id: String) -> some View {
        let value = viewModel.value(of: component)
        let isSelected = viewModel.selectedComponent == component
        return Button {
            viewModel.toggleSelection(component)
        } label: {
            Text(String(format: "%02d", value))
                .frame(
                    minWidth: Theme.Watch.Dimension.digitMinTarget,
                    minHeight: Theme.Watch.Dimension.digitMinTarget
                )
                .background(
                    RoundedRectangle(cornerRadius: Theme.Watch.Dimension.selectionCornerRadius)
                        .fill(isSelected ? Theme.Watch.ColorValue.selection : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue("\(value)")
        .accessibilityHint(Theme.Watch.Label.crownHint)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: viewModel.adjust(component, by: 1)
            case .decrement: viewModel.adjust(component, by: -1)
            @unknown default: break
            }
        }
        .accessibilityIdentifier(id)
    }
}

#Preview {
    NavigationStack {
        WatchTimerView(viewModel: WatchQuickTimerViewModel(timer: TimerViewModel()))
    }
}

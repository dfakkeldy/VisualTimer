import SwiftUI

/// Which part of the time the digital crown is currently adjusting.
enum TimeComponent {
    case minutes
    case seconds
}

/// The main watchOS timer view with digital-crown time adjustment.
///
/// Tapping the minutes or seconds label selects that component for
/// crown adjustment. Tapping it again (or pressing Play) deselects.
struct WatchTimerView: View {

    @StateObject private var viewModel = TimerViewModel()

    // MARK: - Crown State

    @State private var crownValue: Double = 0
    @State private var selectedComponent: TimeComponent? = nil
    @State private var suppressNextCrownChange = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            Spacer()

            // Timer circle
            timerCircle
                .frame(width: 100, height: 100)

            // Selectable time display
            timePicker
                .padding(.top, 4)

            // Controls
            HStack(spacing: 16) {
                // Play / Pause
                Button {
                    selectedComponent = nil
                    switch viewModel.state {
                    case .notStarted, .paused:
                        viewModel.play()
                    case .running:
                        viewModel.pause()
                    case .finished:
                        break
                    }
                } label: {
                    Image(systemName: playPauseIcon)
                        .font(.title2)
                }
                .disabled(viewModel.state == .finished)

                // Reset — only when paused
                if case .paused = viewModel.state {
                    Button {
                        selectedComponent = nil
                        viewModel.reset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                    }
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .focusable(true)
        .digitalCrownRotation(
            $crownValue,
            from: 0, through: 59, by: 1,
            sensitivity: .low,
            isContinuous: false
        )
        .onChange(of: selectedComponent) { component in
            syncCrownToSelection(component)
        }
        .onChange(of: crownValue) { newValue in
            applyCrownChange(Int(newValue))
        }
    }

    // MARK: - Timer Circle

    private var timerCircle: some View {
        TimelineView(.animation(paused: !viewModel.visualProgress.isRunning)) { timeline in
            let elapsed = viewModel.visualProgress.elapsedFraction(at: timeline.date)
            ZStack {
                Circle()
                    .fill(Color(white: 0.15))

                Circle()
                    .trim(from: elapsed, to: 1.0)
                    .stroke(viewModel.timerColor, lineWidth: 14)
                    .rotationEffect(.degrees(-90))
            }
        }
    }

    // MARK: - Time Picker

    private var timePicker: some View {
        HStack(spacing: 2) {
            // Minutes
            Button {
                toggleSelection(.minutes)
            } label: {
                Text(String(format: "%02d", viewModel.totalDuration / 60))
                    .font(.system(.title, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedComponent == .minutes
                                ? Color.red.opacity(0.3) : Color.clear)
                    )
            }
            .buttonStyle(.plain)

            Text(":")
                .font(.system(.title, design: .monospaced))

            // Seconds
            Button {
                toggleSelection(.seconds)
            } label: {
                Text(String(format: "%02d", viewModel.totalDuration % 60))
                    .font(.system(.title, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedComponent == .seconds
                                ? Color.red.opacity(0.3) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var playPauseIcon: String {
        switch viewModel.state {
        case .notStarted, .paused: return "play.fill"
        case .running: return "pause.fill"
        case .finished: return "play.fill"
        }
    }

    private func toggleSelection(_ component: TimeComponent) {
        if selectedComponent == component {
            selectedComponent = nil
        } else {
            selectedComponent = component
        }
    }

    /// Snaps the crown value to the current value of the newly selected
    /// component and suppresses the ensuing `onChange` so it doesn't
    /// feed back into a duration change.
    private func syncCrownToSelection(_ component: TimeComponent?) {
        guard let component else { return }
        suppressNextCrownChange = true
        switch component {
        case .minutes:
            crownValue = Double(viewModel.totalDuration / 60)
        case .seconds:
            crownValue = Double(viewModel.totalDuration % 60)
        }
    }

    private func applyCrownChange(_ newValue: Int) {
        if suppressNextCrownChange {
            suppressNextCrownChange = false
            return
        }

        guard let selected = selectedComponent else { return }

        switch selected {
        case .minutes:
            let seconds = viewModel.totalDuration % 60
            let newMinutes = max(0, min(59, newValue))
            viewModel.setDuration(newMinutes * 60 + seconds)

        case .seconds:
            let minutes = viewModel.totalDuration / 60
            let newSeconds = max(0, min(59, newValue))
            viewModel.setDuration(minutes * 60 + newSeconds)
        }
    }
}

#Preview {
    WatchTimerView()
}

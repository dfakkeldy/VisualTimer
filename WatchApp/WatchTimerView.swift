import SwiftUI

enum TimeComponent {
    case minutes
    case seconds
}

struct WatchTimerView: View {
    @StateObject private var viewModel = WatchTimerViewModel()

    @State private var selectedTemplate = WatchTemplateLibrary.templates[0]
    @State private var crownValue: Double = 0
    @State private var selectedComponent: TimeComponent?
    @State private var suppressNextCrownChange = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    templatePicker

                    timerCircle
                        .frame(width: 96, height: 96)
                        .padding(.top, 4)

                    timePicker

                    controls
                }
                .padding(.vertical, 6)
            }
            .navigationTitle("Turn Timer")
        }
        .focusable(true)
        .digitalCrownRotation(
            $crownValue,
            from: 0,
            through: 59,
            by: 1,
            sensitivity: .low,
            isContinuous: false
        )
        .onChange(of: selectedComponent) { _, component in
            syncCrownToSelection(component)
        }
        .onChange(of: crownValue) { _, newValue in
            applyCrownChange(Int(newValue))
        }
        .onAppear {
            viewModel.apply(template: selectedTemplate)
        }
    }

    private var templatePicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(WatchTemplateLibrary.templates) { template in
                    Button {
                        selectedTemplate = template
                        selectedComponent = nil
                        viewModel.apply(template: template)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.title)
                                .font(.caption.bold())
                                .lineLimit(1)
                            Text(template.subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 116, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedTemplate == template ? viewModel.timerColor : .gray)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var timerCircle: some View {
        let elapsed = viewModel.totalDuration > 0
            ? Double(viewModel.totalDuration - viewModel.timeRemaining) / Double(viewModel.totalDuration)
            : 0.0

        return ZStack {
            Circle()
                .fill(Color.white.opacity(0.14))

            Circle()
                .trim(from: elapsed, to: 1)
                .stroke(viewModel.timerColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: elapsed)

            Text(statusText)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(12)
        }
    }

    private var timePicker: some View {
        HStack(spacing: 2) {
            componentButton(.minutes, value: viewModel.timeRemaining / 60)

            Text(":")
                .font(.system(.title2, design: .monospaced))

            componentButton(.seconds, value: viewModel.timeRemaining % 60)
        }
    }

    private func componentButton(_ component: TimeComponent, value: Int) -> some View {
        Button {
            toggleSelection(component)
        } label: {
            Text(String(format: "%02d", value))
                .font(.system(.title2, design: .monospaced).bold())
                .frame(minWidth: 42)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(selectedComponent == component ? viewModel.timerColor.opacity(0.32) : .clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.state == .running)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                selectedComponent = nil
                switch viewModel.state {
                case .notStarted, .paused, .finished:
                    viewModel.play()
                case .running:
                    viewModel.pause()
                }
            } label: {
                Image(systemName: playPauseIcon)
                    .font(.title3)
            }

            Button {
                selectedComponent = nil
                viewModel.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title3)
            }
            .disabled(viewModel.state == .notStarted)
        }
    }

    private var playPauseIcon: String {
        switch viewModel.state {
        case .notStarted, .paused, .finished:
            return "play.fill"
        case .running:
            return "pause.fill"
        }
    }

    private var statusText: String {
        switch viewModel.state {
        case .notStarted:
            return selectedTemplate.title
        case .running:
            return "Running"
        case .paused:
            return "Paused"
        case .finished:
            return "Done"
        }
    }

    private func toggleSelection(_ component: TimeComponent) {
        guard viewModel.state != .running else { return }
        selectedComponent = selectedComponent == component ? nil : component
    }

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

        guard let selectedComponent else { return }

        switch selectedComponent {
        case .minutes:
            let seconds = viewModel.totalDuration % 60
            viewModel.setDuration(newValue * 60 + seconds)
        case .seconds:
            let minutes = viewModel.totalDuration / 60
            viewModel.setDuration(minutes * 60 + newValue)
        }
    }
}

#Preview {
    WatchTimerView()
}

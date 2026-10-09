import Combine
import Foundation

// MARK: - Controls

/// The part of an idle duration the Digital Crown edits.
enum WatchTimeComponent: Equatable {
    case minutes
    case seconds
}

/// The large primary control on Watch timer screens for a timer state.
enum WatchPrimaryControl: Equatable {
    case start
    case pause
    case resume

    /// Nil for `.finished`, which immediately resets to `.notStarted`.
    init?(state: TimerState) {
        switch state {
        case .notStarted: self = .start
        case .running: self = .pause
        case .paused: self = .resume
        case .finished: return nil
        }
    }

    var title: String {
        switch self {
        case .start: return Theme.Label.start
        case .pause: return Theme.Label.pause
        case .resume: return Theme.Label.resume
        }
    }

    var symbol: String {
        switch self {
        case .start, .resume: return Theme.Symbol.play
        case .pause: return Theme.Symbol.pause
        }
    }
}

/// Formats remaining seconds for Watch digits and VoiceOver.
enum WatchTimeText {
    static func clock(_ seconds: Int) -> String {
        let clamped = max(seconds, 0)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    static func spoken(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .full
        return formatter.string(from: TimeInterval(max(seconds, 0))) ?? clock(seconds)
    }
}

// MARK: - Quick Timer View Model

/// Owns Watch Quick Timer interaction: truthful remaining-time digits,
/// idle-only Digital Crown editing and the Start/Pause/Resume/Reset flow.
///
/// `TimerViewModel` stays the single source of timer state. This model only
/// decides which edits and transitions the Watch screen offers.
@MainActor
final class WatchQuickTimerViewModel: ObservableObject {

    /// Crown range for both minutes and seconds.
    static let componentRange = 0...59

    let timer: TimerViewModel

    @Published private(set) var selectedComponent: WatchTimeComponent?

    /// Bound to the Digital Crown. Applies to the selected component only
    /// while the timer is idle; otherwise it is ignored.
    @Published var crownValue: Double = 0 {
        didSet { applyCrownValue() }
    }

    private var isSnappingCrown = false
    private var timerChanges: AnyCancellable?

    init(timer: TimerViewModel) {
        self.timer = timer
        // Forward timer changes so views observing this model stay current.
        timerChanges = timer.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: - Presentation

    var primaryControl: WatchPrimaryControl? {
        WatchPrimaryControl(state: timer.state)
    }

    var showsReset: Bool {
        timer.state == .paused
    }

    var canEditDuration: Bool {
        timer.state == .notStarted
    }

    /// Remaining seconds from the timer's Date-based progress. Equals the
    /// configured duration while idle and stays correct between ticks.
    func displayedSeconds(at date: Date) -> Int {
        timer.visualProgress.remainingSeconds(at: date)
    }

    /// The configured value of one component, which is what the crown edits.
    func value(of component: WatchTimeComponent) -> Int {
        switch component {
        case .minutes: return timer.totalDuration / 60
        case .seconds: return timer.totalDuration % 60
        }
    }

    // MARK: - Actions

    func toggleSelection(_ component: WatchTimeComponent) {
        guard canEditDuration else {
            selectedComponent = nil
            return
        }
        selectedComponent = selectedComponent == component ? nil : component
        if let selectedComponent {
            // Snap the crown to the current value without treating it as an edit.
            isSnappingCrown = true
            crownValue = Double(clamp(value(of: selectedComponent)))
            isSnappingCrown = false
        }
    }

    /// VoiceOver adjustable action; follows the same idle-only rule as the crown.
    func adjust(_ component: WatchTimeComponent, by delta: Int) {
        set(component, to: value(of: component) + delta)
    }

    func performPrimaryAction(at date: Date = Date()) {
        selectedComponent = nil
        switch timer.state {
        case .notStarted, .paused:
            timer.play(at: date)
        case .running:
            timer.pause(at: date)
        case .finished:
            break
        }
    }

    func reset() {
        selectedComponent = nil
        timer.reset()
    }

    // MARK: - Private

    private func applyCrownValue() {
        guard !isSnappingCrown, let selectedComponent else { return }
        set(selectedComponent, to: Int(crownValue.rounded()))
    }

    private func set(_ component: WatchTimeComponent, to newValue: Int) {
        guard canEditDuration else { return }
        let clamped = clamp(newValue)
        let minutes = component == .minutes ? clamped : value(of: .minutes)
        let seconds = component == .seconds ? clamped : value(of: .seconds)
        timer.setDuration(minutes * 60 + seconds)
    }

    private func clamp(_ value: Int) -> Int {
        min(max(value, Self.componentRange.lowerBound), Self.componentRange.upperBound)
    }
}

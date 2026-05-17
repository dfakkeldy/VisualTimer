import SwiftUI
import Combine

// MARK: - Timer State

/// The four discrete states of the single-timer state machine.
enum TimerState {
    /// User can adjust duration; Play button is shown.
    case notStarted
    /// Timer is counting down; Pause button is shown.
    case running
    /// Timer is halted with remaining time preserved; Unpause and Reset buttons are shown.
    case paused
    /// Timer reached zero — triggers sound, then immediately auto-resets to `.notStarted`.
    case finished
}

// MARK: - Timer View Model

/// Owns the timer-state machine, the Combine-powered countdown,
/// and the screen-sleep lock while the timer is running.
///
/// All mutations flow through the four public transition methods
/// (`play`, `pause`, `reset`, `setDuration`), each of which guards
/// against invalid state transitions so the UI can call them
/// unconditionally.
final class TimerViewModel: ObservableObject {

    // MARK: - Published State

    @Published var state: TimerState = .notStarted
    @Published var timeRemaining: Int
    @Published var totalDuration: Int

    /// Called exactly once when the timer transitions to `.finished`,
    /// before the automatic reset to `.notStarted`.
    var onFinish: (() -> Void)?

    // MARK: - Persistence

    /// Persists the chosen duration across app launches.
    /// Defaults to 25 seconds when no previous value exists.
    @AppStorage("savedTimerDuration") private var savedDuration: Int = 25

    // MARK: - Private

    private var timerSubscription: AnyCancellable?

    private let tickInterval: TimeInterval = 1.0

    // MARK: - Lifecycle

    init() {
        let stored = UserDefaults.standard.integer(forKey: "savedTimerDuration")
        let duration = stored > 0 ? stored : 25
        self.totalDuration = duration
        self.timeRemaining = duration
    }

    // MARK: - State Machine Transitions

    /// Starts or resumes the countdown. Allowed from `.notStarted` and `.paused`.
    /// Keeps the screen awake while the timer is active.
    func play() {
        switch state {
        case .notStarted, .paused:
            state = .running
#if !os(watchOS)
            UIApplication.shared.isIdleTimerDisabled = true
#endif
            beginCountdown()
        case .running, .finished:
            break
        }
    }

    /// Pauses the countdown, preserving remaining time.
    /// Releases the screen-sleep lock.
    func pause() {
        guard case .running = state else { return }
        state = .paused
#if !os(watchOS)
        UIApplication.shared.isIdleTimerDisabled = false
#endif
        endCountdown()
    }

    /// Resets remaining time to the full duration and returns to `.notStarted`.
    /// Releases the screen-sleep lock.
    func reset() {
        guard case .paused = state else { return }
        state = .notStarted
#if !os(watchOS)
        UIApplication.shared.isIdleTimerDisabled = false
#endif
        timeRemaining = totalDuration
    }

    /// Adjusts the timer duration and persists the new value so it
    /// becomes the default for future launches. Only permitted before
    /// the timer starts, so the running or paused timer is never disrupted.
    func setDuration(_ duration: Int) {
        guard case .notStarted = state else { return }
        totalDuration = duration
        timeRemaining = duration
        savedDuration = duration
    }

    // MARK: - Countdown Engine

    /// Fires a 1 Hz timer on the main runloop. Each tick decrements
    /// `timeRemaining` by one. When it reaches zero the timer finishes,
    /// the sound callback fires, and the state machine auto-resets.
    private func beginCountdown() {
        timerSubscription = Timer
            .publish(every: tickInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.handleTimerTick()
            }
    }

    private func endCountdown() {
        timerSubscription?.cancel()
        timerSubscription = nil
    }

    private func handleTimerTick() {
        guard case .running = state else { return }

        if timeRemaining > 0 {
            timeRemaining -= 1
        }

        if timeRemaining == 0 {
            endCountdown()
#if !os(watchOS)
            UIApplication.shared.isIdleTimerDisabled = false
#endif
            state = .finished
            onFinish?()
            timeRemaining = totalDuration
            state = .notStarted
        }
    }
}

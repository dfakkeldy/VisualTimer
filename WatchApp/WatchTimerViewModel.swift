import Combine
import SwiftUI

enum WatchTimerState {
    case notStarted
    case running
    case paused
    case finished
}

@MainActor
final class WatchTimerViewModel: ObservableObject {
    @Published private(set) var state: WatchTimerState = .notStarted
    @Published private(set) var totalDuration: Int
    @Published private(set) var timeRemaining: Int
    @Published private(set) var timerColor: Color = .cyan

    private var ticker: AnyCancellable?

    init(duration: Int = 25) {
        let clampedDuration = Self.clampedDuration(duration)
        totalDuration = clampedDuration
        timeRemaining = clampedDuration
    }

    func apply(template: WatchTemplate) {
        timerColor = color(for: template)
        setDuration(template.firstDurationSeconds)
    }

    func setDuration(_ duration: Int) {
        let clampedDuration = Self.clampedDuration(duration)
        stopTicker()
        totalDuration = clampedDuration
        timeRemaining = clampedDuration
        state = .notStarted
    }

    func play() {
        guard state != .running else { return }
        if state == .finished {
            reset()
        }
        state = .running
        startTicker()
    }

    func pause() {
        guard state == .running else { return }
        stopTicker()
        state = .paused
    }

    func reset() {
        stopTicker()
        timeRemaining = totalDuration
        state = .notStarted
    }

    private func startTicker() {
        stopTicker()
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func tick() {
        guard timeRemaining > 1 else {
            timeRemaining = 0
            stopTicker()
            state = .finished
            return
        }
        timeRemaining -= 1
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func color(for template: WatchTemplate) -> Color {
        switch template.id {
        case "game-night":
            return .orange
        case "recipe-steps":
            return .mint
        case "plant-watering":
            return .green
        default:
            return .cyan
        }
    }

    private static func clampedDuration(_ duration: Int) -> Int {
        max(5, min(59 * 60 + 59, duration))
    }
}

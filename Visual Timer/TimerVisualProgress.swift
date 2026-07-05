import Foundation

struct TimerVisualProgress: Equatable {
    let totalDuration: TimeInterval

    private let elapsedBeforeCurrentRun: TimeInterval
    private let currentRunStartedAt: Date?

    var isRunning: Bool {
        currentRunStartedAt != nil
    }

    init(totalDuration: Int) {
        self.init(
            totalDuration: TimeInterval(max(totalDuration, 0)),
            elapsedBeforeCurrentRun: 0,
            currentRunStartedAt: nil
        )
    }

    private init(
        totalDuration: TimeInterval,
        elapsedBeforeCurrentRun: TimeInterval,
        currentRunStartedAt: Date?
    ) {
        let clampedDuration = max(totalDuration, 0)
        self.totalDuration = clampedDuration
        self.elapsedBeforeCurrentRun = min(max(elapsedBeforeCurrentRun, 0), clampedDuration)
        self.currentRunStartedAt = currentRunStartedAt
    }

    func running(from date: Date = Date()) -> TimerVisualProgress {
        TimerVisualProgress(
            totalDuration: totalDuration,
            elapsedBeforeCurrentRun: elapsedSeconds(at: date),
            currentRunStartedAt: date
        )
    }

    func paused(at date: Date = Date()) -> TimerVisualProgress {
        TimerVisualProgress(
            totalDuration: totalDuration,
            elapsedBeforeCurrentRun: elapsedSeconds(at: date),
            currentRunStartedAt: nil
        )
    }

    func elapsedFraction(at date: Date = Date()) -> Double {
        guard totalDuration > 0 else { return 0 }
        return elapsedSeconds(at: date) / totalDuration
    }

    private func elapsedSeconds(at date: Date) -> TimeInterval {
        var elapsed = elapsedBeforeCurrentRun
        if let currentRunStartedAt {
            elapsed += max(date.timeIntervalSince(currentRunStartedAt), 0)
        }
        return min(max(elapsed, 0), totalDuration)
    }
}

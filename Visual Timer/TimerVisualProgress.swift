import Foundation
import SwiftUI

struct TimerVisualProgress: Equatable {
    let totalDuration: TimeInterval

    private let elapsedBeforeCurrentRun: TimeInterval
    private let currentRunStartedAt: Date?

    var isRunning: Bool {
        currentRunStartedAt != nil
    }

    /// The exact moment a running countdown reaches zero, or nil while it
    /// is idle or paused. Completion notifications are scheduled for this date.
    var finishDate: Date? {
        guard let currentRunStartedAt else { return nil }
        return currentRunStartedAt.addingTimeInterval(totalDuration - elapsedBeforeCurrentRun)
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

    /// Integer countdown and pie derive from the same elapsed-time state.
    /// Round up so a partly elapsed final second still displays one.
    func remainingSeconds(at date: Date = Date()) -> Int {
        Int(ceil(max(totalDuration - elapsedSeconds(at: date), 0)))
    }

    private func elapsedSeconds(at date: Date) -> TimeInterval {
        var elapsed = elapsedBeforeCurrentRun
        if let currentRunStartedAt {
            elapsed += max(date.timeIntervalSince(currentRunStartedAt), 0)
        }
        return min(max(elapsed, 0), totalDuration)
    }
}

/// Saved with an active session so a countdown can resume exactly after the
/// app is closed.
extension TimerVisualProgress: Codable {}

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

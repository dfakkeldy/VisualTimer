import Foundation

/// Keeps a started quick timer across an app close, like a session.
/// Malformed or stale data is discarded rather than restored.
struct QuickTimerStore {
    struct Snapshot: Codable {
        var totalDuration: Int
        var progress: TimerVisualProgress
        var isRunning: Bool
        var colorIndex: Int
        var savedAt: Date
    }

    /// A quick timer older than this is not worth bringing back.
    static let staleAge: TimeInterval = 4 * 60 * 60

    private let url: URL

    init(directory: URL? = nil) {
        let base = directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("QuickTimer.json")
    }

    /// Saves a running or paused quick timer; clears the file otherwise.
    func save(_ timer: TimerViewModel) {
        switch timer.state {
        case .running, .paused:
            let snapshot = Snapshot(
                totalDuration: timer.totalDuration,
                progress: timer.visualProgress,
                isRunning: timer.state == .running,
                colorIndex: timer.timerColorIndex,
                savedAt: Date()
            )
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        case .notStarted, .finished:
            clear()
        }
    }

    /// Puts a saved quick timer back. Returns false when there is nothing
    /// worth restoring.
    @discardableResult
    func restore(into timer: TimerViewModel, now: Date = Date()) -> Bool {
        guard timer.state == .notStarted, let data = try? Data(contentsOf: url) else { return false }
        guard let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              now.timeIntervalSince(snapshot.savedAt) < Self.staleAge else {
            clear()
            return false
        }
        timer.timerColorIndex = snapshot.colorIndex
        timer.restore(
            totalDuration: snapshot.totalDuration,
            progress: snapshot.progress,
            state: snapshot.isRunning ? .running : .paused,
            color: nil
        )
        return true
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}

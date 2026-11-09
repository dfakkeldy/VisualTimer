import Foundation

/// Immutable identities, names, and targets as they were when recording began.
struct StopwatchSource: Codable, Equatable {
    struct Step: Codable, Equatable, Identifiable {
        let id: UUID
        let name: String
        let targetSeconds: Int?
    }

    let templateID: UUID
    let title: String
    let steps: [Step]

    func validate() throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !steps.isEmpty, steps.count <= StopwatchLimits.maximumSteps,
              Set(steps.map(\.id)).count == steps.count,
              steps.allSatisfy({ step in
                  !step.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  (step.targetSeconds.map { (1...Int(StopwatchLimits.maximumStepSeconds)).contains($0) } ?? true)
              }) else { throw StopwatchError.invalidSource }
    }
}

enum StopwatchLimits {
    static let maximumSteps = 1_000
    static let duplicateTapInterval: TimeInterval = 0.35
    static let displayRefreshInterval: TimeInterval = 0.1
    static let maximumStepSeconds: TimeInterval = 86_400
    static let minimumTemplateSeconds = 5
}

struct StopwatchMeasurement: Codable, Equatable, Identifiable {
    let stepID: UUID
    let seconds: TimeInterval
    var id: UUID { stepID }

    /// Countdown templates use whole seconds and have a five-second minimum.
    var templateSeconds: Int {
        Int(min(StopwatchLimits.maximumStepSeconds,
                max(Double(StopwatchLimits.minimumTemplateSeconds), seconds.rounded())))
    }
}

struct StopwatchRecording: Codable, Equatable, Identifiable {
    static let schemaVersion = 1
    let version: Int
    let id: UUID
    let source: StopwatchSource
    let startedAt: Date
    let finishedAt: Date
    let measurements: [StopwatchMeasurement]

    var isComplete: Bool { measurements.count == source.steps.count }
    var totalSeconds: TimeInterval { measurements.reduce(0) { $0 + $1.seconds } }

    func validate() throws {
        try source.validate()
        guard version == Self.schemaVersion,
              startedAt.timeIntervalSince1970.isFinite, finishedAt.timeIntervalSince1970.isFinite,
              !measurements.isEmpty,
              measurements.map(\.stepID) == Array(source.steps.prefix(measurements.count)).map(\.id),
              measurements.count <= source.steps.count,
              measurements.allSatisfy({ $0.seconds.isFinite && (0...StopwatchLimits.maximumStepSeconds).contains($0.seconds) })
        else { throw StopwatchError.invalidRecording }
    }
}

enum StopwatchError: LocalizedError {
    case invalidSource
    case invalidRecording
    case changedTemplate

    var errorDescription: String? {
        switch self {
        case .invalidSource:
            return Theme.Stopwatch.invalidSource
        case .invalidRecording:
            return Theme.Stopwatch.invalidRecording
        case .changedTemplate:
            return Theme.Stopwatch.changedTemplate
        }
    }
}

/// Pure, guarded stopwatch state machine. Clock values are injected monotonic seconds;
/// wall dates are metadata only. Background time counts; paused time never does.
struct StopwatchSession {
    enum Phase: Equatable { case ready, running, paused, review, discarded }

    let source: StopwatchSource
    private(set) var phase: Phase = .ready
    private(set) var index = 0
    private(set) var measurements: [StopwatchMeasurement] = []
    private(set) var recording: StopwatchRecording?
    private var accumulated: TimeInterval = 0
    private var anchor: TimeInterval?
    private var startedAt: Date?
    private var lastAdvanceTime: TimeInterval?
    private let recordingID = UUID()

    init(source: StopwatchSource) {
        self.source = source
    }

    var currentStep: StopwatchSource.Step? {
        source.steps.indices.contains(index) ? source.steps[index] : nil
    }

    func elapsed(at time: TimeInterval) -> TimeInterval {
        guard phase == .running, let anchor, time.isFinite else { return accumulated }
        return min(StopwatchLimits.maximumStepSeconds, accumulated + max(0, time - anchor))
    }

    mutating func start(at time: TimeInterval, date: Date) throws {
        guard phase == .ready else { return }
        try source.validate()
        guard time.isFinite, date.timeIntervalSince1970.isFinite else { throw StopwatchError.invalidRecording }
        startedAt = date
        anchor = time
        phase = .running
    }

    mutating func pause(at time: TimeInterval) {
        guard phase == .running, time.isFinite else { return }
        accumulated = elapsed(at: time)
        anchor = nil
        phase = .paused
    }

    mutating func resume(at time: TimeInterval) {
        guard phase == .paused, time.isFinite, accumulated < StopwatchLimits.maximumStepSeconds else { return }
        anchor = time
        phase = .running
    }

    /// The expected identity rejects taps delivered from a now-stale step control.
    mutating func next(expectedStepID: UUID, at time: TimeInterval, date: Date) {
        guard (phase == .running || phase == .paused), time.isFinite,
              currentStep?.id == expectedStepID,
              lastAdvanceTime.map({ time - $0 >= StopwatchLimits.duplicateTapInterval }) ?? true else { return }
        lastAdvanceTime = time
        if index == source.steps.count - 1 {
            finish(expectedStepID: expectedStepID, at: time, date: date)
            return
        }
        measurements.append(StopwatchMeasurement(stepID: expectedStepID, seconds: elapsed(at: time)))
        index += 1
        accumulated = 0
        // Next explicitly starts the next step, even when the previous step was paused.
        anchor = time
        phase = .running
    }

    mutating func finish(expectedStepID: UUID, at time: TimeInterval, date: Date) {
        guard (phase == .running || phase == .paused), time.isFinite,
              date.timeIntervalSince1970.isFinite,
              currentStep?.id == expectedStepID, let startedAt else { return }
        accumulated = elapsed(at: time)
        measurements.append(StopwatchMeasurement(stepID: expectedStepID, seconds: accumulated))
        recording = StopwatchRecording(version: StopwatchRecording.schemaVersion, id: recordingID,
            source: source, startedAt: startedAt, finishedAt: date, measurements: measurements)
        anchor = nil
        phase = .review
    }

    mutating func discard() {
        guard phase != .discarded else { return }
        measurements = []
        recording = nil
        accumulated = 0
        anchor = nil
        phase = .discarded
    }
}

/// A continuous clock includes device sleep, unlike an accumulating UI timer.
/// The periodic publisher only refreshes the display; it never measures time.
enum StopwatchClock {
    private static let origin = ContinuousClock.now
    static func now() -> TimeInterval {
        let components = origin.duration(to: ContinuousClock.now).components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

/// Shared, bounded formatting used by controls, charts, and their text alternatives.
enum StopwatchText {
    static func elapsed(_ seconds: TimeInterval) -> String {
        let safe = min(StopwatchLimits.maximumStepSeconds, max(0, seconds.isFinite ? seconds : 0))
        let tenths = Int((safe * 10).rounded(.down))
        let hours = tenths / 36_000
        let minutes = (tenths / 600) % 60
        let remainder = (tenths / 10) % 60
        if hours > 0 { return String(format: "%d:%02d:%02d.%d", hours, minutes, remainder, tenths % 10) }
        return String(format: "%d:%02d.%d", minutes, remainder, tenths % 10)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let value = Int(min(StopwatchLimits.maximumStepSeconds * Double(StopwatchLimits.maximumSteps),
                            max(0, seconds.isFinite ? seconds : 0)).rounded())
        let hours = value / 3_600
        let minutes = (value % 3_600) / 60
        let remainder = value % 60
        if hours > 0 { return "\(hours)h \(minutes)m \(remainder)s" }
        if minutes > 0 { return "\(minutes)m \(remainder)s" }
        return "\(remainder)s"
    }

    static func comparison(step: StopwatchSource.Step, actual: TimeInterval) -> String {
        Theme.Stopwatch.comparison(target: step.targetSeconds.map { duration(Double($0)) },
                                   actual: duration(actual),
                                   difference: step.targetSeconds.map { actual - Double($0) })
    }
}

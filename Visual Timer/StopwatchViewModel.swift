import Foundation
import Combine

/// Owns planning, recording, local persistence, review, and chart projections.
final class StopwatchViewModel: ObservableObject {
    struct TrendPoint: Identifiable {
        let id: UUID
        let date: Date
        let step: StopwatchSource.Step
        let seconds: TimeInterval
    }

    struct ComparisonRow: Identifiable {
        let step: StopwatchSource.Step
        let measurement: StopwatchMeasurement
        let position: Int
        var id: UUID { step.id }
        var label: String { "\(position). \(step.name)" }
        var summary: String { StopwatchText.comparison(step: step, actual: measurement.seconds) }
    }

    var reviewRows: [ComparisonRow] {
        guard let reviewRecord else { return [] }
        return reviewRecord.measurements.enumerated().compactMap { index, measurement in
            guard let step = reviewRecord.source.steps.first(where: { $0.id == measurement.stepID }) else { return nil }
            return ComparisonRow(step: step, measurement: measurement, position: index + 1)
        }
    }

    let isNewRoutine: Bool
    let isLibrary: Bool
    private let savedTemplateIDs: Set<UUID>
    @Published private(set) var source: StopwatchSource
    @Published private(set) var session: StopwatchSession?
    @Published private(set) var reviewRecord: StopwatchRecording?
    @Published private(set) var records: [StopwatchRecording] = []
    @Published private(set) var isReviewSaved = false
    @Published private(set) var isApplied = false
    @Published private(set) var displaySeconds: TimeInterval = 0
    @Published private(set) var unreadableCount = 0
    @Published var errorMessage: String?
    @Published var selectedTrendStepID: UUID?
    @Published var isProUnlocked: Bool

    private let store: StopwatchRecordingStorage
    private let now: () -> TimeInterval
    private let date: () -> Date
    private var ticker: AnyCancellable?

    init(source: StopwatchSource, isNewRoutine: Bool = false, isProUnlocked: Bool,
         isLibrary: Bool = false, savedTemplateIDs: Set<UUID> = [],
         store: StopwatchRecordingStorage = StopwatchRecordingStore(),
         now: @escaping () -> TimeInterval = StopwatchClock.now,
         date: @escaping () -> Date = Date.init,
         automaticallyRefresh: Bool = true) {
        self.source = source
        self.isNewRoutine = isNewRoutine
        self.isLibrary = isLibrary
        self.savedTemplateIDs = savedTemplateIDs
        self.isProUnlocked = isProUnlocked
        self.store = store
        self.now = now
        self.date = date
        selectedTrendStepID = source.steps.first?.id
        reload()
        if automaticallyRefresh {
            ticker = Timer.publish(every: StopwatchLimits.displayRefreshInterval, on: .main, in: .common).autoconnect()
                .sink { [weak self] _ in self?.refreshTime() }
        }
    }

    var isRecording: Bool { session?.phase == .running || session?.phase == .paused }
    var hasUnkeptRecording: Bool { isRecording || (reviewRecord != nil && !isReviewSaved) }
    var canStart: Bool { (try? source.validate()) != nil }
    var visibleRecords: [StopwatchRecording] {
        // Apply the existing history limit before filtering by routine.
        let accessible = isProUnlocked ? records : Array(records.prefix(HistoryAccessPolicy.freeRecordLimit))
        return isLibrary ? accessible : accessible.filter { $0.source.templateID == source.templateID }
    }
    var hasOlderRecords: Bool {
        let relevant = isLibrary ? records : records.filter { $0.source.templateID == source.templateID }
        return visibleRecords.count < relevant.count
    }
    var sourceValidationMessage: String? {
        do { try source.validate(); return nil }
        catch { return error.localizedDescription }
    }
    var appliesAsNewRoutine: Bool {
        isNewRoutine || (isLibrary && reviewRecord?.source.templateID != source.templateID)
    }
    var needsSourceTemplate: Bool {
        guard isLibrary, let reviewRecord else { return false }
        return reviewRecord.source.templateID != source.templateID && savedTemplateIDs.contains(reviewRecord.source.templateID)
    }
    var canApply: Bool {
        guard let reviewRecord, !isApplied, !needsSourceTemplate else { return false }
        return !appliesAsNewRoutine || reviewRecord.isComplete
    }
    var trendSteps: [StopwatchSource.Step] {
        var seen = Set<UUID>()
        return (source.steps + visibleRecords.flatMap { $0.source.steps }).filter { seen.insert($0.id).inserted }
    }
    var trendPoints: [TrendPoint] {
        guard let selectedTrendStepID else { return [] }
        return visibleRecords.reversed().compactMap { record in
            guard record.source.templateID == source.templateID,
                  let step = record.source.steps.first(where: { $0.id == selectedTrendStepID }),
                  let measurement = record.measurements.first(where: { $0.stepID == selectedTrendStepID }) else { return nil }
            return TrendPoint(id: record.id, date: record.startedAt, step: step, seconds: measurement.seconds)
        }
    }

    func setTitle(_ title: String) {
        guard isNewRoutine, session == nil, reviewRecord == nil else { return }
        source = StopwatchSource(templateID: source.templateID, title: title, steps: source.steps)
    }

    func renameStep(id: UUID, name: String) {
        guard isNewRoutine, session == nil, reviewRecord == nil else { return }
        source = StopwatchSource(templateID: source.templateID, title: source.title,
            steps: source.steps.map { $0.id == id ? .init(id: id, name: name, targetSeconds: nil) : $0 })
    }

    func addStep() {
        guard isNewRoutine, session == nil, reviewRecord == nil,
              source.steps.count < StopwatchLimits.maximumSteps else { return }
        let step = StopwatchSource.Step(id: UUID(), name: "", targetSeconds: nil)
        source = StopwatchSource(templateID: source.templateID, title: source.title, steps: source.steps + [step])
        if selectedTrendStepID == nil { selectedTrendStepID = step.id }
    }

    func removeSteps(at offsets: IndexSet) {
        guard isNewRoutine, session == nil, reviewRecord == nil else { return }
        source = StopwatchSource(templateID: source.templateID, title: source.title,
            steps: source.steps.enumerated().filter { !offsets.contains($0.offset) }.map(\.element))
        if !source.steps.contains(where: { $0.id == selectedTrendStepID }) {
            selectedTrendStepID = source.steps.first?.id
        }
    }

    func moveSteps(from offsets: IndexSet, to destination: Int) {
        guard isNewRoutine, session == nil, reviewRecord == nil else { return }
        // Keep this model independent of SwiftUI's Array.move helper.
        var steps = source.steps
        let moved = offsets.sorted().compactMap { steps.indices.contains($0) ? steps[$0] : nil }
        for offset in offsets.sorted(by: >) where steps.indices.contains(offset) { steps.remove(at: offset) }
        let insertion = min(steps.count, max(0, destination - offsets.filter { $0 < destination }.count))
        steps.insert(contentsOf: moved, at: insertion)
        source = StopwatchSource(templateID: source.templateID, title: source.title, steps: steps)
    }

    func start() {
        guard session == nil, reviewRecord == nil else { return }
        do {
            var next = StopwatchSession(source: source)
            try next.start(at: now(), date: date())
            session = next
            displaySeconds = 0
        } catch { errorMessage = error.localizedDescription }
    }

    func refreshTime() {
        guard let session, isRecording else { return }
        displaySeconds = session.elapsed(at: now())
        if displaySeconds >= StopwatchLimits.maximumStepSeconds, session.phase == .running {
            self.session?.pause(at: now())
        }
    }

    func pause() { session?.pause(at: now()); refreshTime() }
    func resume() { session?.resume(at: now()); refreshTime() }

    func next(stepID: UUID) {
        session?.next(expectedStepID: stepID, at: now(), date: date())
        receiveTransition()
    }

    func finish(stepID: UUID) {
        session?.finish(expectedStepID: stepID, at: now(), date: date())
        receiveTransition()
    }

    private func receiveTransition() {
        if let record = session?.recording, reviewRecord == nil {
            reviewRecord = record
            isReviewSaved = false
            isApplied = false
        }
        displaySeconds = session?.elapsed(at: now()) ?? 0
    }

    func discardUnkeptRecording() {
        session?.discard()
        session = nil
        reviewRecord = nil
        isReviewSaved = false
        isApplied = false
        displaySeconds = 0
    }

    func show(_ record: StopwatchRecording) {
        guard !hasUnkeptRecording, visibleRecords.contains(where: { $0.id == record.id }) else { return }
        session = nil
        reviewRecord = record
        isReviewSaved = true
        isApplied = false
    }

    func backToPlan() {
        guard !hasUnkeptRecording else { return }
        session = nil
        reviewRecord = nil
        isApplied = false
        displaySeconds = 0
    }

    @discardableResult
    func saveReview() -> Bool {
        guard let reviewRecord else { return false }
        if isReviewSaved { return true }
        do {
            try store.save(reviewRecord)
            isReviewSaved = true
            reload()
            return true
        } catch {
            errorMessage = "Recording could not be saved on this device: \(error.localizedDescription) Try again before closing."
            return false
        }
    }

    @discardableResult
    func applyReview(_ apply: (StopwatchRecording) throws -> Void) -> Bool {
        guard canApply, let reviewRecord, saveReview() else { return false }
        do {
            try apply(reviewRecord)
            isApplied = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteReview() {
        guard isReviewSaved, let record = reviewRecord else { return }
        do {
            try store.delete(id: record.id)
            reviewRecord = nil
            session = nil
            isReviewSaved = false
            reload()
        } catch { errorMessage = "Recording could not be deleted: \(error.localizedDescription)" }
    }

    func reload() {
        do {
            let loaded = try store.load(templateID: nil)
            records = loaded.records
            unreadableCount = loaded.unreadableFiles.count
        } catch { errorMessage = "Local recordings could not be loaded: \(error.localizedDescription)" }
    }
}

import Foundation
import Combine

/// Owns planning, recording, local persistence, review, and chart projections.
final class StopwatchViewModel: ObservableObject {
    enum Mode { case template, newPlan, library }
    enum ApplyKind { case existingTemplate, newTemplate }
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
        var appliedDurationHint: String? {
            measurement.adjustsForTemplate ? Theme.Stopwatch.setsDuration(measurement.templateSeconds) : nil
        }
    }

    var reviewRows: [ComparisonRow] {
        guard let reviewRecord else { return [] }
        return reviewRecord.measurements.enumerated().compactMap { index, measurement in
            guard let step = reviewRecord.source.steps.first(where: { $0.id == measurement.stepID }) else { return nil }
            return ComparisonRow(step: step, measurement: measurement, position: index + 1)
        }
    }

    let mode: Mode
    var isNewRoutine: Bool { mode == .newPlan }
    var isLibrary: Bool { mode == .library }
    private let savedTemplateTitles: [UUID: String]
    private let initialPlan: StopwatchSource
    private var planBaseline: StopwatchSource
    @Published private(set) var source: StopwatchSource
    @Published private(set) var session: StopwatchSession?
    @Published private(set) var reviewRecord: StopwatchRecording?
    @Published private(set) var records: [StopwatchRecording] = []
    @Published private(set) var isReviewSaved = false
    @Published private(set) var isApplied = false
    @Published private(set) var displaySeconds: TimeInterval = 0
    @Published private(set) var unreadableCount = 0
    @Published private(set) var hasLoadFailure = false
    @Published var errorMessage: String?
    @Published var selectedTrendStepID: UUID?
    @Published var isProUnlocked: Bool

    private let store: StopwatchRecordingStorage
    private let now: @MainActor () -> TimeInterval
    private let date: () -> Date
    private let applyPreflight: (StopwatchRecording, ApplyKind) -> StopwatchError?
    private var ticker: AnyCancellable?

    init(source: StopwatchSource, mode: Mode = .template, isProUnlocked: Bool,
         savedTemplateTitles: [UUID: String] = [:],
         applyPreflight: @escaping (StopwatchRecording, ApplyKind) -> StopwatchError? = { _, _ in nil },
         store: StopwatchRecordingStorage = StopwatchRecordingStore(),
         now: @escaping @MainActor () -> TimeInterval = StopwatchClock.now,
         date: @escaping () -> Date = Date.init,
         automaticallyRefresh: Bool = true) {
        self.source = source
        self.initialPlan = source
        self.planBaseline = source
        self.mode = mode
        self.savedTemplateTitles = savedTemplateTitles
        self.applyPreflight = applyPreflight
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
    private var hasUnsavedPlanEdits: Bool { isNewRoutine && source != planBaseline }
    var hasUnkeptPlan: Bool {
        hasUnsavedPlanEdits && session == nil && reviewRecord == nil
    }
    var hasUnkeptWork: Bool { hasUnkeptRecording || hasUnkeptPlan }
    var canDiscardRecordingKeepingPlan: Bool { isNewRoutine && hasUnkeptRecording }
    var discardAction: String {
        if canDiscardRecordingKeepingPlan && hasUnsavedPlanEdits { return Theme.Stopwatch.discardRecordingAndPlan }
        return hasUnkeptPlan ? Theme.Stopwatch.discardPlan : Theme.Stopwatch.discard
    }
    var workspaceStatus: String {
        if isRecording, let session {
            return Theme.Stopwatch.progress(position: session.index + 1, count: session.source.steps.count,
                                            isPaused: session.phase == .paused)
        }
        return hasUnkeptPlan ? Theme.Stopwatch.unsavedPlan : Theme.Stopwatch.unsavedReview
    }
    var discardTitle: String {
        hasUnkeptPlan ? Theme.Stopwatch.discardPlanTitle
            : (isRecording ? Theme.Stopwatch.discardTitle : Theme.Stopwatch.discardReviewTitle)
    }
    var discardHint: String {
        if canDiscardRecordingKeepingPlan {
            return hasUnsavedPlanEdits ? Theme.Stopwatch.discardPlanAndRecordingHint
                : Theme.Stopwatch.discardRecordingKeepingPlanHint
        }
        return hasUnkeptPlan ? Theme.Stopwatch.discardPlanHint
            : (isRecording ? Theme.Stopwatch.discardHint : Theme.Stopwatch.discardReviewHint)
    }
    var unmeasuredStepCount: Int {
        guard isRecording, let session else { return 0 }
        return max(0, session.source.steps.count - session.index - 1)
    }
    var finishEarlyHint: String {
        Theme.Stopwatch.finishEarlyHint(current: session?.currentStep?.name,
                                       count: unmeasuredStepCount, isNewRoutine: isNewRoutine)
    }
    var hasReachedStepLimit: Bool { displaySeconds >= StopwatchLimits.maximumStepSeconds }
    var currentStepAnnouncement: String? {
        guard isRecording, let session, let step = session.currentStep else { return nil }
        return Theme.Stopwatch.stepAnnouncement(position: session.index + 1, count: session.source.steps.count, name: step.name)
    }
    var canStart: Bool { session == nil && reviewRecord == nil && startBlocker == nil }
    private var routineRecords: [StopwatchRecording] {
        isLibrary ? records : records.filter { $0.source.templateID == source.templateID }
    }
    var visibleRecords: [StopwatchRecording] {
        // Apply the existing history limit before filtering by routine.
        let accessibleIDs = Set(HistoryAccessPolicy.visibleRecords(records, isProUnlocked: isProUnlocked).map(\.id))
        return routineRecords.filter { accessibleIDs.contains($0.id) }
    }
    var hasOlderRecords: Bool { visibleRecords.count < routineRecords.count }
    var startBlocker: String? {
        let problem: String
        if source.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            problem = Theme.Stopwatch.missingRoutineName
        } else if source.steps.isEmpty {
            problem = Theme.Stopwatch.missingSteps
        } else if let index = source.steps.firstIndex(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            problem = Theme.Stopwatch.missingStepName(index + 1)
        } else {
            do { try source.validate(); return nil }
            catch { problem = error.localizedDescription }
        }
        return mode == .template ? Theme.Stopwatch.fixInTemplateEditor(problem) : problem
    }
    var applyKind: ApplyKind {
        isNewRoutine || (isLibrary && reviewRecord?.source.templateID != source.templateID) ? .newTemplate : .existingTemplate
    }
    var needsSourceTemplate: Bool {
        guard isLibrary, let reviewRecord else { return false }
        return reviewRecord.source.templateID != source.templateID && savedTemplateTitles[reviewRecord.source.templateID] != nil
    }
    var openSourceHint: String {
        guard let reviewRecord else { return "" }
        return Theme.Stopwatch.openSourceHint(savedTemplateTitles[reviewRecord.source.templateID] ?? reviewRecord.source.title)
    }
    var canApply: Bool {
        guard let reviewRecord, !isApplied, !needsSourceTemplate else { return false }
        return applyKind == .existingTemplate || reviewRecord.isComplete
    }
    var applyBlocker: StopwatchError? {
        guard canApply, let reviewRecord else { return nil }
        return applyPreflight(reviewRecord, applyKind)
    }
    var applyBlockerMessage: String? {
        guard let blocker = applyBlocker else { return nil }
        if case .changedTemplate = blocker, !isReviewSaved {
            return Theme.Stopwatch.saveFirst(blocker.localizedDescription)
        }
        return blocker.localizedDescription
    }
    func trendStepLabel(_ step: StopwatchSource.Step) -> String {
        source.steps.contains(where: { $0.id == step.id }) ? step.name : Theme.Stopwatch.earlierStep(step.name)
    }
    var trendSteps: [StopwatchSource.Step] {
        let measuredIDs = Set(visibleRecords.flatMap { $0.measurements.map(\.stepID) })
        var seen = Set<UUID>()
        return (source.steps + visibleRecords.flatMap { $0.source.steps }).filter {
            measuredIDs.contains($0.id) && seen.insert($0.id).inserted
        }
    }
    var trendSelection: UUID? {
        let steps = trendSteps
        return steps.contains(where: { $0.id == selectedTrendStepID }) ? selectedTrendStepID : steps.first?.id
    }
    var trendPoints: [TrendPoint] {
        guard let selectedTrendStepID = trendSelection else { return [] }
        return visibleRecords.reversed().compactMap { record in
            guard let step = record.source.steps.first(where: { $0.id == selectedTrendStepID }),
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

    func discardUnkeptWork() {
        discardUnkeptRecording()
        if isNewRoutine { source = planBaseline }
    }

    func show(_ record: StopwatchRecording) {
        guard !hasUnkeptWork, visibleRecords.contains(where: { $0.id == record.id }) else { return }
        session = nil
        reviewRecord = record
        isReviewSaved = true
        isApplied = false
    }

    func backToPlan() {
        guard !hasUnkeptWork else { return }
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
            if isNewRoutine { planBaseline = source }
            reload()
            return true
        } catch {
            errorMessage = Theme.Stopwatch.saveError(error.localizedDescription)
            return false
        }
    }

    @discardableResult
    func applyReview(_ apply: (StopwatchRecording) throws -> Void) -> Bool {
        guard canApply, let reviewRecord else { return false }
        if let blocker = applyBlocker {
            errorMessage = blocker.localizedDescription
            return false
        }
        guard saveReview() else { return false }
        do {
            try apply(reviewRecord)
            isApplied = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func deleteReview() -> Bool {
        guard isReviewSaved, let record = reviewRecord else { return false }
        do {
            try store.delete(id: record.id)
            reviewRecord = nil
            session = nil
            isReviewSaved = false
            // Do not retain the deleted baseline even if the subsequent reload fails.
            records.removeAll { $0.id == record.id }
            reload()
            if isNewRoutine {
                planBaseline = records.first { $0.source.templateID == source.templateID }?.source ?? initialPlan
            }
            return true
        } catch {
            errorMessage = Theme.Stopwatch.deleteError(error.localizedDescription)
            return false
        }
    }

    func reload() {
        do {
            let loaded = try store.load()
            records = loaded.records
            unreadableCount = loaded.unreadableFiles.count
            hasLoadFailure = false
        } catch {
            hasLoadFailure = true
            errorMessage = Theme.Stopwatch.loadError(error.localizedDescription)
        }
    }
}

/// Retains one workspace across safe sheet dismissal and the editor's paywall.
/// Presentation callbacks are explicit so the two sheets never overlap.
final class StopwatchWorkspace: ObservableObject {
    @Published private(set) var model: StopwatchViewModel?
    @Published var isPresented = false
    private var pendingProFeature: ProFeature?

    var hasUnkeptWork: Bool { model?.hasUnkeptWork == true }

    func open(_ model: StopwatchViewModel) {
        guard !hasUnkeptWork, !isPresented, pendingProFeature == nil else { return }
        self.model = model
        isPresented = true
    }

    func returnToStopwatch() {
        guard model != nil, pendingProFeature == nil else { return }
        isPresented = true
    }

    func requestPro(_ feature: ProFeature) {
        guard model != nil, isPresented, pendingProFeature == nil else { return }
        pendingProFeature = feature
        isPresented = false
    }

    func sheetDidDismiss() -> ProFeature? {
        if let pendingProFeature { return pendingProFeature }
        if !hasUnkeptWork { model = nil }
        return nil
    }

    func updateProAccess(_ unlocked: Bool) {
        model?.isProUnlocked = unlocked
    }

    func paywallDidDismiss(isProUnlocked: Bool) {
        updateProAccess(isProUnlocked)
        guard pendingProFeature != nil, model != nil else { return }
        pendingProFeature = nil
        isPresented = true
    }
}

import SwiftUI

/// Feature container for a name-only plan or the current template's stopwatch.
/// All timing, persistence, projections, and editing decisions belong to models.
struct StopwatchView: View {
    @ObservedObject var model: StopwatchViewModel
    let replacesUnsavedEdits: Bool
    let onApply: (StopwatchRecording) throws -> Void
    let onClose: () -> Void
    let onRequestPro: (ProFeature) -> Void

    private enum FocusTarget: Hashable { case review, start, history }
    @AccessibilityFocusState private var focusedElement: FocusTarget?

    @State private var showDiscard = false
    @State private var showUndoPlanEdits = false
    @State private var showDelete = false
    @State private var showReplace = false
    @State private var showFinishEarly = false
    @State private var earlyFinishStepID: UUID?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                if model.isRecording, let session = model.session, let step = session.currentStep {
                    recordingSections(session: session, step: step)
                } else if let record = model.reviewRecord {
                    reviewSections(record: record)
                } else {
                    if !model.isLibrary { planSections }
                    historySections
                }
            }
            .id(model.isRecording ? "recording" : (model.reviewRecord?.id.uuidString ?? "plan"))
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.ColorValue.appBackground)
            .navigationTitle(model.isLibrary ? Theme.Stopwatch.recordingsEntry : Theme.Stopwatch.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    closeButton
                }
            }
            .confirmationDialog(model.discardTitle, isPresented: $showDiscard, titleVisibility: .visible) {
                if model.canDiscardRecordingKeepingPlan {
                    Button(Theme.Stopwatch.discardMeasurementsKeepingPlan, role: .destructive) {
                        model.discardUnkeptRecording()
                    }
                }
                Button(model.discardAction, role: .destructive) {
                    model.discardUnkeptWork()
                    onClose()
                }
                Button(model.isRecording ? Theme.Stopwatch.keepRecording : Theme.Stopwatch.cancel, role: .cancel) {}
            } message: { Text(model.discardHint) }
            .confirmationDialog(Theme.Stopwatch.undoPlanEditsTitle,
                                isPresented: $showUndoPlanEdits, titleVisibility: .visible) {
                Button(Theme.Stopwatch.undoPlanEdits, role: .destructive) { model.discardUnkeptWork() }
                Button(Theme.Stopwatch.cancel, role: .cancel) {}
            } message: { Text(Theme.Stopwatch.discardPlanHint) }
            .confirmationDialog(Theme.Stopwatch.finishEarlyTitle,
                                isPresented: $showFinishEarly,
                                titleVisibility: .visible) {
                Button(Theme.Stopwatch.finishEarly) {
                    if let stepID = earlyFinishStepID { model.finish(stepID: stepID) }
                    earlyFinishStepID = nil
                }
                Button(Theme.Stopwatch.keepRecording, role: .cancel) { earlyFinishStepID = nil }
            } message: { Text(model.finishEarlyHint) }
            .confirmationDialog(Theme.Stopwatch.deleteTitle, isPresented: $showDelete, titleVisibility: .visible) {
                Button(Theme.Stopwatch.deleteRecording, role: .destructive) {
                    if model.deleteReview() { announce(Theme.Stopwatch.recordingDeleted) }
                }
                Button(Theme.Stopwatch.cancel, role: .cancel) {}
            } message: { Text(Theme.Stopwatch.deleteHint) }
            .confirmationDialog(Theme.Stopwatch.replaceTitle, isPresented: $showReplace, titleVisibility: .visible) {
                Button(Theme.Stopwatch.applyNew, role: .destructive) { apply() }
                Button(Theme.Stopwatch.cancel, role: .cancel) {}
            } message: { Text(Theme.Stopwatch.replaceHint) }
            .alert(Theme.Stopwatch.errorTitle,
                   isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                Button(Theme.Stopwatch.ok) { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
            .onChange(of: model.reviewRecord?.id) { _, id in
                focusedElement = id != nil ? .review : (model.isLibrary ? .history : .start)
            }
            .onChange(of: model.session?.index) { _, _ in
                if let message = model.currentStepAnnouncement { announce(message) }
            }
            .onChange(of: model.hasReachedStepLimit) { _, reached in
                if reached { announce(Theme.Stopwatch.limitHint) }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { model.refreshTime() }
            }
        }
    }

    private func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }

    @ViewBuilder
    private var closeButton: some View {
        if #available(iOS 26.0, *) {
            Button(role: .close, action: requestClose) { Image(systemName: Theme.Stopwatch.closeSymbol) }
                .accessibilityLabel(Theme.Stopwatch.close)
        } else {
            Button(action: requestClose) { Image(systemName: Theme.Stopwatch.closeSymbol) }
                .accessibilityLabel(Theme.Stopwatch.close)
        }
    }

    private func requestClose() {
        if model.hasUnkeptWork { showDiscard = true } else { onClose() }
    }

    @ViewBuilder
    private var planSections: some View {
        Section {
            if model.isNewRoutine {
                TextField(Theme.Stopwatch.routineName,
                          text: Binding(get: { model.source.title }, set: model.setTitle))
                    .font(.title2.weight(.bold))
            } else {
                Text(model.source.title).font(.title2.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
            }
            Text(model.isNewRoutine ? Theme.Stopwatch.newHint : Theme.Stopwatch.existingHint)
                .foregroundStyle(Theme.ColorValue.textSecondary)
            Label(Theme.Stopwatch.localHint, systemImage: Theme.Stopwatch.localSymbol)
                .font(.caption)
            Text(Theme.Stopwatch.backgroundHint)
                .font(.caption)
                .foregroundStyle(Theme.ColorValue.textSecondary)
        } header: { Text(Theme.Stopwatch.planTitle) }
        .listRowBackground(Theme.ColorValue.surface)

        Section {
            ForEach(Array(model.source.steps.enumerated()), id: \.element.id) { index, step in
                planStepRow(index: index, step: step)
            }
            .onDelete { offsets in
                guard model.isNewRoutine else { return }
                model.removeSteps(at: offsets)
            }
            .onMove { offsets, destination in
                guard model.isNewRoutine else { return }
                model.moveSteps(from: offsets, to: destination)
            }
            .deleteDisabled(!model.isNewRoutine)
            .moveDisabled(!model.isNewRoutine)
            if model.isNewRoutine {
                Button(action: model.addStep) { Label(Theme.Stopwatch.addStep, systemImage: Theme.Stopwatch.addSymbol) }
            }
            Button(Theme.Stopwatch.start, action: model.start)
                .font(.headline)
                .disabled(!model.canStart)
                .accessibilityIdentifier(Theme.Stopwatch.startIdentifier)
                .accessibilityFocused($focusedElement, equals: .start)
                .accessibilityHint(model.startBlocker ?? "")
            if let message = model.startBlocker {
                Text(message).font(.caption)
            }
        } footer: {
            Text(model.isNewRoutine ? Theme.Stopwatch.planHint : Theme.Stopwatch.sourceHint)
        }
        .listRowBackground(Theme.ColorValue.surface)
    }

    @ViewBuilder
    private func planStepRow(index: Int, step: StopwatchSource.Step) -> some View {
        if model.isNewRoutine {
            HStack {
                TextField(Theme.Stopwatch.stepName(index + 1),
                          text: Binding(get: { step.name }, set: { model.renameStep(id: step.id, name: $0) }))
                    .accessibilityLabel(Theme.Stopwatch.stepName(index + 1))
                Menu {
                    stepActions(index: index)
                } label: {
                    Image(systemName: Theme.Stopwatch.optionsSymbol)
                        .frame(minWidth: Theme.Stopwatch.minimumTarget, minHeight: Theme.Stopwatch.minimumTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Theme.Stopwatch.stepOptions(index + 1))
            }
            .accessibilityActions { stepActions(index: index) }
        } else {
            VStack(alignment: .leading, spacing: Theme.Stopwatch.smallSpacing) {
                Text(step.name).font(.headline)
                if let target = step.targetSeconds {
                    Text("\(Theme.Stopwatch.target): \(StopwatchText.duration(Double(target)))")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ColorValue.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func stepActions(index: Int) -> some View {
        Button {
            model.moveSteps(from: IndexSet(integer: index), to: index - 1)
        } label: { Label(Theme.Stopwatch.moveUp, systemImage: Theme.Stopwatch.moveUpSymbol) }
            .disabled(index == 0)
        Button {
            model.moveSteps(from: IndexSet(integer: index), to: index + 2)
        } label: { Label(Theme.Stopwatch.moveDown, systemImage: Theme.Stopwatch.moveDownSymbol) }
            .disabled(index == model.source.steps.count - 1)
        Button(role: .destructive) {
            model.removeSteps(at: IndexSet(integer: index))
        } label: { Label(Theme.Stopwatch.deleteStep, systemImage: Theme.Stopwatch.deleteSymbol) }
    }

    @ViewBuilder
    private func recordingSections(session: StopwatchSession, step: StopwatchSource.Step) -> some View {
        Section {
            StopwatchLiveDisplay(step: step, position: session.index + 1, count: model.source.steps.count,
                                 seconds: model.displaySeconds, isPaused: session.phase == .paused)
            if model.displaySeconds >= StopwatchLimits.maximumStepSeconds {
                Text(Theme.Stopwatch.limitHint).font(.subheadline)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Stopwatch.spacing) { recordingControls(session: session, step: step) }
                VStack(spacing: Theme.Stopwatch.spacing) { recordingControls(session: session, step: step) }
            }
            if session.index < model.source.steps.count - 1 {
                Button(Theme.Stopwatch.finishEarly) {
                    earlyFinishStepID = step.id
                    showFinishEarly = true
                }
                    .accessibilityIdentifier(Theme.Stopwatch.finishEarlyIdentifier)
            }
        } footer: {
            Text(session.phase == .paused ? Theme.Stopwatch.pausedHint : Theme.Stopwatch.backgroundHint)
        }
        .listRowBackground(Theme.ColorValue.surface)

        Section {
            ForEach(Array(model.source.steps.enumerated()), id: \.element.id) { index, item in
                Label(item.name, systemImage: index < session.index ? Theme.Stopwatch.completedSymbol
                      : (index == session.index ? Theme.Stopwatch.currentSymbol : Theme.Stopwatch.upcomingSymbol))
                    .foregroundStyle(index == session.index ? Theme.ColorValue.textPrimary : Theme.ColorValue.textSecondary)
                    .accessibilityValue(index < session.index ? Theme.Stopwatch.completed : (index == session.index ? Theme.Stopwatch.currentStep : Theme.Stopwatch.upcoming))
            }
        } header: { Text(model.source.title) }
        .listRowBackground(Theme.ColorValue.surface)
    }

    @ViewBuilder
    private func recordingControls(session: StopwatchSession, step: StopwatchSource.Step) -> some View {
        Button {
            if session.phase == .paused {
                model.resume()
                announce(Theme.Stopwatch.recording)
            } else {
                model.pause()
                announce(Theme.Stopwatch.paused)
            }
        } label: {
            Label(session.phase == .paused ? Theme.Stopwatch.resume : Theme.Stopwatch.pause,
                  systemImage: session.phase == .paused ? Theme.Stopwatch.resumeSymbol : Theme.Stopwatch.pauseSymbol)
                .foregroundStyle(Theme.ColorValue.textPrimary)
        }
        .disabled(model.hasReachedStepLimit)
        .buttonStyle(.bordered)
        Button { model.next(stepID: step.id) } label: {
            Label(session.index == model.source.steps.count - 1 ? Theme.Stopwatch.finish : Theme.Stopwatch.next,
                  systemImage: session.index == model.source.steps.count - 1 ? Theme.Symbol.checkmark : Theme.Stopwatch.nextSymbol)
                .foregroundStyle(Theme.ColorValue.textPrimary)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.Stopwatch.prominentTint)
        .accessibilityIdentifier(session.index == model.source.steps.count - 1 ? Theme.Stopwatch.finishIdentifier : Theme.Stopwatch.nextIdentifier)
    }

    @ViewBuilder
    private func reviewSections(record: StopwatchRecording) -> some View {
        let blocker = model.applyBlockerMessage
        Section {
            Text(record.source.title).font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusedElement, equals: .review)
            Text(record.startedAt.formatted(date: .abbreviated, time: .standard))
                .foregroundStyle(Theme.ColorValue.textSecondary)
            Text(model.isReviewSaved ? Theme.Stopwatch.saved : Theme.Stopwatch.notSaved)
                .font(.subheadline.weight(.semibold))
            if model.isNewRoutine && model.isReviewSaved {
                Text(Theme.Stopwatch.savedNewRoutineHint).font(.caption)
            }
            StopwatchComparisonView(rows: model.reviewRows)
        } header: { Text(Theme.Stopwatch.review) }
        .listRowBackground(Theme.ColorValue.surface)

        Section {
            Button(model.isReviewSaved ? Theme.Stopwatch.savedAction : Theme.Stopwatch.saveRecording) {
                if model.saveReview() { announce(Theme.Stopwatch.savedAction) }
            }
                .disabled(model.isReviewSaved)
            Button(model.applyKind == .newTemplate ? Theme.Stopwatch.applyNew : Theme.Stopwatch.apply) {
                if model.applyKind == .newTemplate && replacesUnsavedEdits { showReplace = true } else { apply() }
            }
            .font(.headline)
            .disabled(!model.canApply || blocker != nil)
            .accessibilityIdentifier(Theme.Stopwatch.applyIdentifier)
            if let blocker {
                Text(blocker).font(.subheadline)
            } else if model.needsSourceTemplate {
                Text(model.openSourceHint).font(.subheadline)
            }
            if !record.isComplete {
                Text(model.applyKind == .newTemplate ? Theme.Stopwatch.partialNewHint : Theme.Stopwatch.partialHint)
                    .font(.subheadline)
            }
            if model.isReviewSaved {
                Button(model.isLibrary ? Theme.Stopwatch.allRecordings : Theme.Stopwatch.recordAgain, action: model.backToPlan)
                Button(Theme.Stopwatch.deleteRecording, role: .destructive) { showDelete = true }
            }
        } footer: { Text(Theme.Stopwatch.applyHint) }
        .listRowBackground(Theme.ColorValue.surface)
    }

    @ViewBuilder
    private var historySections: some View {
        Section {
            if model.hasUnkeptPlan {
                Text(Theme.Stopwatch.historyBlockedByPlan).font(.caption)
                Button(Theme.Stopwatch.undoPlanEdits, role: .destructive) { showUndoPlanEdits = true }
            }
            if model.visibleRecords.isEmpty {
                ContentUnavailableView(model.hasOlderRecords ? Theme.Stopwatch.noRecentRecordings : Theme.Stopwatch.emptyTitle, systemImage: Theme.Stopwatch.emptySymbol,
                                       description: Text(model.hasOlderRecords ? Theme.Stopwatch.historyLimit : Theme.Stopwatch.emptyHint))
            } else {
                ForEach(model.visibleRecords) { record in
                    Button { model.show(record) } label: {
                        VStack(alignment: .leading, spacing: Theme.Stopwatch.smallSpacing) {
                            Text(record.startedAt.formatted(date: .abbreviated, time: .standard))
                                .font(.headline)
                            Text(record.source.title)
                                .font(.subheadline)
                                .foregroundStyle(Theme.ColorValue.textSecondary)
                            Text(Theme.Stopwatch.recordingSummary(measured: record.measurements.count, total: record.source.steps.count,
                                                                duration: StopwatchText.duration(record.totalSeconds)))
                                .font(.caption)
                                .foregroundStyle(Theme.ColorValue.textSecondary)
                        }
                    }
                    .disabled(model.hasUnkeptPlan)
                }
            }
            if model.unreadableCount > 0 {
                Text(Theme.Stopwatch.unreadableFiles(model.unreadableCount))
                    .font(.caption)
            }
            if model.unreadableCount > 0 || model.hasLoadFailure {
                Button(Theme.Stopwatch.retryLoading, action: model.reload)
            }
            if model.hasOlderRecords {
                if !model.visibleRecords.isEmpty { Text(Theme.Stopwatch.historyLimit).font(.caption) }
                Button(Theme.Stopwatch.unlockHistory) { onRequestPro(.fullHistory) }
            }
        } header: {
            Text(Theme.Stopwatch.history)
                .accessibilityFocused($focusedElement, equals: .history)
        } footer: { Text(Theme.Stopwatch.localHint) }
        .listRowBackground(Theme.ColorValue.surface)

        if !model.isLibrary && !model.visibleRecords.isEmpty {
            Section {
                Picker(Theme.Stopwatch.chooseStep, selection: Binding(
                    get: { model.trendSelection }, set: { model.selectedTrendStepID = $0 })) {
                    ForEach(model.trendSteps) { step in Text(model.trendStepLabel(step)).tag(Optional(step.id)) }
                }
                StopwatchTrendView(points: model.trendPoints)
            } header: { Text(Theme.Stopwatch.trend) }
            .listRowBackground(Theme.ColorValue.surface)
        }
    }

    private func apply() {
        if model.applyReview(onApply) { onClose() }
    }
}

/// Stateless current-step readout that scales with Dynamic Type.
private struct StopwatchLiveDisplay: View {
    let step: StopwatchSource.Step
    let position: Int
    let count: Int
    let seconds: TimeInterval
    let isPaused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Stopwatch.spacing) {
            Text(Theme.Stopwatch.progress(position: position, count: count, isPaused: isPaused))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ColorValue.textSecondary)
            Text(step.name).font(.largeTitle.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text(StopwatchText.elapsed(seconds))
                .font(.largeTitle.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.Stopwatch.actualColor)
                .accessibilityLabel(Theme.Stopwatch.elapsed(StopwatchText.duration(seconds)))
                .accessibilityIdentifier(Theme.Stopwatch.elapsedIdentifier)
                .accessibilityAddTraits(.updatesFrequently)
            if let target = step.targetSeconds {
                Text("\(Theme.Stopwatch.target): \(StopwatchText.duration(Double(target)))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }
        }
        .padding(.vertical, Theme.Stopwatch.smallSpacing)
    }
}

import SwiftUI

struct StopwatchWorkspace: Identifiable {
    let id = UUID()
    let model: StopwatchViewModel
}

/// Feature container for a name-only plan or the current template's stopwatch.
/// All timing, persistence, projections, and editing decisions belong to models.
struct StopwatchView: View {
    @ObservedObject var model: StopwatchViewModel
    @ObservedObject var proAccess: ProAccessViewModel
    let replacesUnsavedEdits: Bool
    let onApply: (StopwatchRecording) throws -> Void
    let onClose: () -> Void

    @State private var showDiscard = false
    @State private var showDelete = false
    @State private var showReplace = false
    @State private var requestedProFeature: ProFeature?
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
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.ColorValue.appBackground)
            .navigationTitle(Theme.Stopwatch.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Theme.Stopwatch.close) {
                        if model.hasUnkeptRecording { showDiscard = true } else { onClose() }
                    }
                }
            }
            .interactiveDismissDisabled(model.hasUnkeptRecording)
            .confirmationDialog(Theme.Stopwatch.discardTitle, isPresented: $showDiscard, titleVisibility: .visible) {
                Button(Theme.Stopwatch.discard, role: .destructive) {
                    model.discardUnkeptRecording()
                    onClose()
                }
                Button(Theme.Stopwatch.keepRecording, role: .cancel) {}
            } message: { Text(Theme.Stopwatch.discardHint) }
            .confirmationDialog(Theme.Stopwatch.deleteTitle, isPresented: $showDelete, titleVisibility: .visible) {
                Button(Theme.Stopwatch.deleteRecording, role: .destructive) { model.deleteReview() }
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
            .sheet(item: $requestedProFeature) { feature in
                ProPaywallView(feature: feature, proAccess: proAccess)
            }
            .onChange(of: proAccess.isProUnlocked) { _, value in model.isProUnlocked = value }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { model.refreshTime() }
            }
        }
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
            ForEach(model.source.steps) { step in
                if model.isNewRoutine {
                    TextField(Theme.Stopwatch.stepName,
                              text: Binding(get: { step.name }, set: { model.renameStep(id: step.id, name: $0) }))
                        .accessibilityLabel(Theme.Stopwatch.stepName)
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
            .onDelete(perform: model.isNewRoutine ? model.removeSteps : nil)
            .onMove(perform: model.isNewRoutine ? model.moveSteps : nil)
            if model.isNewRoutine {
                Button(action: model.addStep) { Label(Theme.Stopwatch.addStep, systemImage: Theme.Stopwatch.addSymbol) }
            }
            Button(Theme.Stopwatch.start, action: model.start)
                .font(.headline)
                .disabled(!model.canStart)
                .accessibilityIdentifier(Theme.Stopwatch.startIdentifier)
            if !model.isNewRoutine, let message = model.sourceValidationMessage {
                Text(message).font(.caption)
            }
        } footer: {
            Text(model.isNewRoutine ? Theme.Stopwatch.planHint : Theme.Stopwatch.sourceHint)
        }
        .listRowBackground(Theme.ColorValue.surface)
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
                Button(Theme.Stopwatch.finish) { model.finish(stepID: step.id) }
                    .accessibilityIdentifier(Theme.Stopwatch.finishIdentifier)
            }
        } footer: {
            Text(session.phase == .paused ? Theme.Stopwatch.pausedHint : Theme.Stopwatch.backgroundHint)
        }
        .listRowBackground(Theme.ColorValue.surface)

        Section {
            ForEach(Array(model.source.steps.enumerated()), id: \.element.id) { index, item in
                Label(item.name, systemImage: index < session.index ? Theme.Symbol.checkmark : Theme.Stopwatch.planSymbol)
                    .foregroundStyle(index == session.index ? Theme.ColorValue.textPrimary : Theme.ColorValue.textSecondary)
                    .accessibilityValue(index < session.index ? Theme.Stopwatch.completed : (index == session.index ? Theme.Stopwatch.currentStep : Theme.Stopwatch.upcoming))
            }
        } header: { Text(model.source.title) }
        .listRowBackground(Theme.ColorValue.surface)
    }

    @ViewBuilder
    private func recordingControls(session: StopwatchSession, step: StopwatchSource.Step) -> some View {
        if session.phase == .paused {
            Button(action: model.resume) {
                Label(Theme.Stopwatch.resume, systemImage: Theme.Stopwatch.resumeSymbol)
            }
            .disabled(model.displaySeconds >= StopwatchLimits.maximumStepSeconds)
            .buttonStyle(.bordered)
        } else {
            Button(action: model.pause) {
                Label(Theme.Stopwatch.pause, systemImage: Theme.Stopwatch.pauseSymbol)
            }
            .buttonStyle(.bordered)
        }
        Button { model.next(stepID: step.id) } label: {
            Label(session.index == model.source.steps.count - 1 ? Theme.Stopwatch.finish : Theme.Stopwatch.next,
                  systemImage: session.index == model.source.steps.count - 1 ? Theme.Symbol.checkmark : Theme.Stopwatch.nextSymbol)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier(session.index == model.source.steps.count - 1 ? Theme.Stopwatch.finishIdentifier : Theme.Stopwatch.nextIdentifier)
    }

    @ViewBuilder
    private func reviewSections(record: StopwatchRecording) -> some View {
        Section {
            Text(record.source.title).font(.title2.weight(.bold))
            Text(record.startedAt.formatted(date: .abbreviated, time: .standard))
                .foregroundStyle(Theme.ColorValue.textSecondary)
            Text(model.isReviewSaved ? Theme.Stopwatch.saved : Theme.Stopwatch.notSaved)
                .font(.subheadline.weight(.semibold))
            StopwatchComparisonView(rows: model.reviewRows)
        } header: { Text(Theme.Stopwatch.review) }
        .listRowBackground(Theme.ColorValue.surface)

        Section {
            if !model.isReviewSaved {
                Button(Theme.Stopwatch.saveRecording) { model.saveReview() }
            }
            Button(model.appliesAsNewRoutine ? Theme.Stopwatch.applyNew : Theme.Stopwatch.apply) {
                if model.appliesAsNewRoutine && replacesUnsavedEdits { showReplace = true } else { apply() }
            }
            .font(.headline)
            .disabled(!model.canApply)
            .accessibilityIdentifier(Theme.Stopwatch.applyIdentifier)
            if model.needsSourceTemplate {
                Text(Theme.Stopwatch.openSourceHint).font(.subheadline)
            }
            if !record.isComplete {
                Text(model.appliesAsNewRoutine ? Theme.Stopwatch.partialNewHint : Theme.Stopwatch.partialHint)
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
            if model.visibleRecords.isEmpty {
                ContentUnavailableView(model.hasOlderRecords ? Theme.Stopwatch.noRecentRecordings : Theme.Stopwatch.emptyTitle, systemImage: Theme.Stopwatch.emptySymbol,
                                       description: Text(Theme.Stopwatch.emptyHint))
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
                }
            }
            if model.unreadableCount > 0 {
                Text(Theme.Stopwatch.unreadableFiles(model.unreadableCount))
                    .font(.caption)
                Button(Theme.Stopwatch.retryLoading, action: model.reload)
            }
            if model.hasOlderRecords {
                Text(Theme.Stopwatch.historyLimit).font(.caption)
                Button(Theme.Stopwatch.unlockHistory) { requestedProFeature = .fullHistory }
            }
        } header: { Text(Theme.Stopwatch.history) } footer: { Text(Theme.Stopwatch.localHint) }
        .listRowBackground(Theme.ColorValue.surface)

        if !model.isLibrary && !model.visibleRecords.isEmpty {
            Section {
                Picker(Theme.Stopwatch.chooseStep, selection: $model.selectedTrendStepID) {
                    ForEach(model.trendSteps) { step in Text(step.name).tag(Optional(step.id)) }
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
            Text(StopwatchText.elapsed(seconds))
                .font(.largeTitle.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.Stopwatch.actualColor)
                .accessibilityLabel(Theme.Stopwatch.elapsed(StopwatchText.duration(seconds)))
                .accessibilityIdentifier(Theme.Stopwatch.elapsedIdentifier)
            if let target = step.targetSeconds {
                Text("\(Theme.Stopwatch.target): \(StopwatchText.duration(Double(target)))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            }
        }
        .padding(.vertical, Theme.Stopwatch.smallSpacing)
    }
}

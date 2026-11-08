import SwiftUI

/// Root watchOS view: browse a quick timer, starter templates, and saved
/// templates published by the iOS app. Selecting a template starts it in the
/// app-level `WatchAppModel` and presents `WatchGamePlaybackView`; a running
/// session or quick timer survives navigating back here.
struct WatchRootView: View {

    @ObservedObject var model: WatchAppModel

    @Environment(\.scenePhase) private var scenePhase
    @State private var presentingSession = false

    var body: some View {
        NavigationStack {
            List {
                if let session = model.activeSession {
                    Section {
                        Button {
                            presentingSession = true
                        } label: {
                            rowLabel(
                                title: session.isComplete ? Theme.Watch.Label.sessionComplete : Theme.Watch.Label.resumeSession,
                                detail: session.title,
                                systemImage: Theme.Watch.Symbol.resumeSession
                            )
                        }
                        .accessibilityIdentifier(Theme.Watch.Identifier.rootResumeSession)
                    }
                }

                Section {
                    NavigationLink {
                        WatchTimerView(viewModel: model.quickTimer)
                    } label: {
                        rowLabel(
                            title: Theme.Watch.Label.quickTimer,
                            detail: quickTimerStatus,
                            systemImage: Theme.Watch.Symbol.quickTimer,
                            tint: model.quickTimer.timer.timerColor
                        )
                    }
                    .accessibilityIdentifier(Theme.Watch.Identifier.rootQuickTimer)
                }

                // While something runs, the alert offer sits right beside it:
                // in context, when it would help. Otherwise it waits at the end.
                if somethingIsRunning {
                    alertsSection
                }

                if !model.savedTemplates.isEmpty {
                    Section(Theme.Watch.Label.savedTemplates) {
                        ForEach(model.savedTemplates) { template in
                            Button {
                                startSession(template.game)
                            } label: {
                                templateRow(title: template.title, game: template.game)
                            }
                        }
                    }
                }

                Section(Theme.Watch.Label.starterTemplates) {
                    ForEach(StarterTemplateLibrary.templates) { template in
                        Button {
                            startSession(template.game)
                        } label: {
                            templateRow(title: template.title, game: template.game)
                        }
                        .accessibilityIdentifier(Theme.Watch.Identifier.rootStarter(template.id))
                    }
                }

                if !somethingIsRunning {
                    alertsSection
                }
            }
            .navigationDestination(isPresented: $presentingSession) {
                WatchGamePlaybackView(
                    gameViewModel: model.gameViewModel,
                    timerViewModel: model.sessionTimer,
                    onPrimary: { model.toggleSession() },
                    onRestart: { model.restartRound() },
                    onPrevious: { model.previousRound() },
                    onSkip: { model.skipRound() },
                    onEnd: { model.endSession() }
                )
            }
        }
        .task {
            WatchTemplateConnectivity.shared.activate()
            model.refreshSavedTemplates()
            await model.refreshNotificationPermission()
        }
#if DEBUG
        .task {
            // Design-council captures: `-designCouncilWatchSession <starter id>`.
            if let id = UserDefaults.standard.string(forKey: "designCouncilWatchSession"),
               let template = StarterTemplateLibrary.template(id: id) {
                // Let the list finish its first layout so the push isn't dropped.
                try? await Task.sleep(for: .seconds(1.5))
                startSession(template.game)
            }
        }
#endif
        .onReceive(NotificationCenter.default.publisher(for: WatchTemplateConnectivity.templatesChanged)) { _ in
            model.refreshSavedTemplates()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.sceneDidBecomeActive()
            } else {
                model.sceneDidResignActive()
            }
        }
    }

    // MARK: - Alerts

    @ViewBuilder
    private var alertsSection: some View {
        switch model.notificationPermission {
        case .notDetermined:
            Section {
                Button {
                    model.requestNotificationPermission()
                } label: {
                    rowLabel(
                        title: Theme.Watch.Label.allowAlerts,
                        detail: Theme.Watch.Label.allowAlertsShort,
                        systemImage: Theme.Watch.Symbol.allowAlerts
                    )
                }
                .accessibilityIdentifier(Theme.Watch.Identifier.rootAllowAlerts)
            }
        case .denied:
            Section {
                rowLabel(
                    title: Theme.Watch.Label.alertsOff,
                    detail: Theme.Watch.Label.alertsOffDetail,
                    systemImage: Theme.Watch.Symbol.alertsOff
                )
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(Theme.Watch.Identifier.rootAlertsOff)
            }
        case .allowed:
            EmptyView()
        }
    }

    // MARK: - Helpers

    /// A template: its name, its length, and one dot per round in its colour.
    private func templateRow(title: String, game: GameSequence) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if let emoji = game.activeRounds.first(where: { !$0.emoji.isEmpty })?.emoji {
                    Text(emoji)
                }
                Text(title)
                    .lineLimit(1)
            }
            HStack(spacing: 6) {
                // The phone's colour ribbon at wrist scale: one segment per
                // round, as long as its time.
                HStack(spacing: 1.5) {
                    let total = max(game.activeRounds.reduce(0) { $0 + $1.durationSeconds }, 1)
                    ForEach(Array(game.activeRounds.enumerated()), id: \.offset) { _, round in
                        Capsule()
                            .fill(round.color.swiftUIColor)
                            .frame(width: max(54 * CGFloat(round.durationSeconds) / CGFloat(total), 3), height: 5)
                    }
                }
                Text(durationText(for: game))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 3)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(durationText(for: game))
        }
    }

    private func rowLabel(title: String, detail: String?, systemImage: String, tint: Color? = nil) -> some View {
        Label {
            VStack(alignment: .leading) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint ?? .primary)
        }
    }

    private var somethingIsRunning: Bool {
        model.activeSession != nil || model.quickTimerState == .running || model.quickTimerState == .paused
    }

    /// Live state on the row, so a return from the wrist shows where things are.
    private var quickTimerStatus: String? {
        let left = WatchTimeText.clock(model.quickTimer.timer.timeRemaining)
        switch model.quickTimerState {
        case .running: return "\(left) left"
        case .paused: return "\(Theme.Watch.Label.paused) · \(left)"
        case .notStarted, .finished:
            let seconds = model.quickTimer.timer.totalDuration
            return seconds < 60 ? "\(seconds) sec" : "\(Int((Double(seconds) / 60).rounded())) min"
        }
    }

    private func startSession(_ game: GameSequence) {
        model.startSession(game)
        presentingSession = true
    }

    private func durationText(for game: GameSequence) -> String {
        let sequenceSeconds = game.activeRounds.reduce(0) { $0 + $1.durationSeconds }
        let total = sequenceSeconds * max(game.roundCount, 1)
        let minutes = Int((Double(total) / 60).rounded())
        return total < 60 ? "\(total) sec" : "\(minutes) min"
    }
}

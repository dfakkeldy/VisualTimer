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

                alertsSection
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
            HStack(spacing: 3) {
                ForEach(Array(game.activeRounds.prefix(8).enumerated()), id: \.offset) { _, round in
                    Circle()
                        .fill(round.color.swiftUIColor)
                        .frame(width: 6, height: 6)
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

    private var quickTimerStatus: String? {
        switch model.quickTimerState {
        case .running: return Theme.Watch.Label.running
        case .paused: return Theme.Watch.Label.paused
        case .notStarted, .finished: return nil
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

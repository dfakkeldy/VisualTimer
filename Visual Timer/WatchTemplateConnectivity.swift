import Foundation
import OSLog
@preconcurrency import WatchConnectivity

/// Sends the latest saved-template snapshot across devices. App Groups only
/// provide durable storage on each device, not a phone-to-Watch transport.
@MainActor
final class WatchTemplateConnectivity: NSObject, WCSessionDelegate {
    static let shared = WatchTemplateConnectivity()
    static let templatesChanged = Notification.Name("TurnTimerWatchTemplatesChanged")

    private static let fileMarker = "turnTimerTemplateFile"
    private static let revisionKey = "turnTimerWatchPublishRevision"
    private let logger = Logger(subsystem: "Dan.Visual-Timer", category: "WatchTemplates")
    private let store = WatchTemplateStore()
    private let session: WCSession?
    private var deliveryState = WatchTemplateDeliveryState()
    private var retryTask: Task<Void, Never>?

    private override init() {
        session = WCSession.isSupported() ? WCSession.default : nil
        super.init()
        session?.delegate = self
    }

    func activate() {
        guard let session, session.activationState != .activated else { return }
        session.activate()
    }

    func publish(templates: [WatchTemplate]) {
#if os(iOS)
        retryTask?.cancel()
        deliveryState.resetRetries()
        let previous = UserDefaults.standard.double(forKey: Self.revisionKey)
        let revision = UInt64(max(previous + 1, Date().timeIntervalSince1970 * 1_000_000))
        do {
            deliveryState.replace(with: try WatchTemplateStore.applicationContext(for: templates, revision: revision))
            UserDefaults.standard.set(Double(revision), forKey: Self.revisionKey)
            activate()
            sendPendingContext()
        } catch {
            logger.error("Unable to encode Watch template snapshot.")
        }
#endif
    }

    func retryLatestSnapshot() {
        retryTask?.cancel()
        deliveryState.resetRetries()
        activate()
        sendPendingContext()
    }

    private func scheduleRetry() {
        guard let delay = deliveryState.retryDelayAfterFailure() else { return }
        retryTask?.cancel()
        retryTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: delay * 1_000_000_000) }
            catch { return }
            guard !Task.isCancelled else { return }
            self?.sendPendingContext()
        }
    }

    private func sendPendingContext() {
#if os(iOS)
        guard let session, session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled,
              let context = deliveryState.latestContext,
              let data = context[WatchTemplateStore.contextKey] as? Data else { return }
        do {
            // Context replaces older snapshots and does not require reachability.
            try session.updateApplicationContext(context)
            deliveryState.resetRetries()
        } catch {
            // Large snapshots exceed the context limit. File delivery retains the
            // full payload; persisted revisions reject delayed/out-of-order files.
            do {
                let directory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("TurnTimerWatchTransfers", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let file = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
                try data.write(to: file, options: .atomic)
                session.transferFile(file, metadata: [Self.fileMarker: true])
            } catch {
                logger.error("Unable to queue Watch template snapshot.")
            }
        }
#endif
    }

    private func accept(context: [String: Any]) {
#if os(watchOS)
        do {
            if try store.applyApplicationContext(context) {
                NotificationCenter.default.post(name: Self.templatesChanged, object: nil)
            }
        } catch {
            logger.error("Invalid Watch template snapshot; keeping previous templates.")
        }
#endif
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        let context = session.receivedApplicationContext
        Task { @MainActor [weak self] in
            self?.accept(context: context)
            self?.sendPendingContext()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor [weak self] in self?.accept(context: applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // WatchConnectivity removes the temporary received file after this
        // delegate method returns. Read its bytes before crossing to MainActor.
        guard file.metadata?["turnTimerTemplateFile"] as? Bool == true,
              let data = try? Data(contentsOf: file.fileURL) else { return }
        Task { @MainActor [weak self] in
            self?.accept(context: [WatchTemplateStore.contextKey: data])
        }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        guard fileTransfer.file.metadata?["turnTimerTemplateFile"] as? Bool == true else { return }
        let url = fileTransfer.file.fileURL
        let ownedDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TurnTimerWatchTransfers", isDirectory: true).standardizedFileURL
        guard url.deletingLastPathComponent().standardizedFileURL == ownedDirectory else { return }
        try? FileManager.default.removeItem(at: url)
        if error != nil {
            Task { @MainActor [weak self] in
                self?.logger.error("Watch template file delivery failed; retrying latest snapshot.")
                self?.scheduleRetry()
            }
        }
    }

#if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.sendPendingContext() }
    }
#endif
}

import Foundation
import OSLog
@preconcurrency import WatchConnectivity

/// Sends the latest saved-template snapshot across devices. App Groups only
/// provide durable storage on each device, not a phone-to-Watch transport.
@MainActor
final class WatchTemplateConnectivity: NSObject, WCSessionDelegate, LiveRoutineTransport {
    static var supportsLiveRoutine: Bool { WCSession.isSupported() }
    static let shared = WatchTemplateConnectivity()
    static let templatesChanged = Notification.Name("TurnTimerWatchTemplatesChanged")

    private static let fileMarker = "turnTimerTemplateFile"
    private static let revisionKey = "turnTimerWatchPublishRevision"
    private let logger = Logger(subsystem: "Dan.Visual-Timer", category: "WatchTemplates")
    private let store = WatchTemplateStore()
    private let session: WCSession?
    static let liveKey = "turnTimerLiveRoutineV1"
    var connectionChanged: (() -> Void)?
    var receiveLive: ((Data) -> Void)?
    var receiveCommand: ((Data, @escaping (Data) -> Void) -> Void)?
    var reachable: Bool { session?.isReachable == true }
    private var liveData: Data?
    private var lastQueuedLive: Data?

    func replayLiveContext() {
        if let data = session?.receivedApplicationContext[Self.liveKey] as? Data { receiveLive?(data) }
    }

    func publishLive(_ data: Data) {
        liveData = data
        activate()
        sendCombinedContext()
    }

    func sendLiveCommand(_ data: Data, completion: @escaping (Data?) -> Void) {
        guard let session, session.isReachable else { completion(nil); return }
        session.sendMessageData(data, replyHandler: { @Sendable reply in
            Task { @MainActor in completion(reply) }
        }, errorHandler: { @Sendable _ in Task { @MainActor in completion(nil) } })
    }

    /// Keep large template payloads on the existing file channel. A large live
    /// journal also falls back to a file, independently of template delivery.
    static func composedContext(templates: [String: Any]?, live: Data?) -> [String: Any] {
        var context = templates ?? [:]
        if let templateData = context[WatchTemplateStore.contextKey] as? Data, templateData.count > 24_000 {
            context.removeValue(forKey: WatchTemplateStore.contextKey)
        }
        if let live, live.count <= 24_000 { context[liveKey] = live }
        return context
    }

    private func queueFile(_ data: Data, marker: String) {
        guard let session else { return }
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TurnTimerWatchTransfers", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
            try data.write(to: file, options: .atomic)
            session.transferFile(file, metadata: [marker: true])
        } catch { logger.error("Unable to queue companion snapshot."); scheduleRetry() }
    }

    private func sendCombinedContext() {
        guard let session, session.activationState == .activated else { return }
#if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { return }
#endif
        let context = Self.composedContext(templates: deliveryState.latestContext, live: liveData)
        do { try session.updateApplicationContext(context); deliveryState.resetRetries() }
        catch { scheduleRetry() }
        if let liveData, liveData.count > 24_000, liveData != lastQueuedLive {
            lastQueuedLive = liveData; queueFile(liveData, marker: Self.liveKey)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data,
                             replyHandler: @escaping (Data) -> Void) {
        Task { @MainActor [weak self] in
            guard let handler = self?.receiveCommand else { replyHandler(Data()); return }
            handler(messageData, replyHandler)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.sendCombinedContext(); self?.connectionChanged?() }
    }

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
        sendCombinedContext()
#if os(iOS)
        guard let session, session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled,
              let data = deliveryState.latestContext?[WatchTemplateStore.contextKey] as? Data,
              data.count > 24_000 else { return }
        queueFile(data, marker: Self.fileMarker)
#endif
    }

    private func accept(context: [String: Any]) {
        if let data = context[Self.liveKey] as? Data { receiveLive?(data) }
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
            self?.connectionChanged?()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor [weak self] in self?.accept(context: applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // WatchConnectivity removes the temporary received file after this
        // delegate method returns. Read its bytes before crossing to MainActor.
        let live = file.metadata?["turnTimerLiveRoutineV1"] as? Bool == true
        guard live || file.metadata?["turnTimerTemplateFile"] as? Bool == true,
              let data = try? Data(contentsOf: file.fileURL) else { return }
        Task { @MainActor [weak self] in
            self?.accept(context: [live ? Self.liveKey : WatchTemplateStore.contextKey: data])
        }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        guard fileTransfer.file.metadata?["turnTimerTemplateFile"] as? Bool == true || fileTransfer.file.metadata?["turnTimerLiveRoutineV1"] as? Bool == true else { return }
        let url = fileTransfer.file.fileURL
        let ownedDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TurnTimerWatchTransfers", isDirectory: true).standardizedFileURL
        guard url.deletingLastPathComponent().standardizedFileURL == ownedDirectory else { return }
        try? FileManager.default.removeItem(at: url)
        if error != nil {
            Task { @MainActor [weak self] in
                self?.lastQueuedLive = nil
                self?.logger.error("Companion file delivery failed; retrying latest snapshot.")
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

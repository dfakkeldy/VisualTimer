import Foundation
import SwiftUI
import CryptoKit
import Darwin

/// Versioned immutable plan and single-writer state. Occurrence changes even when
/// restarting the same step, so a delayed tap cannot operate on its replacement.
struct LiveRoutineSession: Codable {
    enum Phase: String, Codable { case running, paused, waiting, completed, ended }
    let version: Int
    let id: UUID
    let authority: UUID
    let plan: GameSequence
    let planHash: String
    var revision: UInt64 = 1
    var occurrence: UUID = UUID()
    var step = 0
    var repetition = 1
    var phase: Phase
    var elapsedBeforeRun: TimeInterval = 0
    var anchor: Date?
    let startedAt: Date
    var events: [SessionEvent]
    var processed: [UUID] = []
    struct Summary: Codable {
        let steps: Int
        let skipped: Int
        let duration: TimeInterval
    }
    var summary: Summary?
    func wireSnapshot() -> LiveRoutineSession {
        var copy = self
        copy.summary = Summary(steps: events.filter { if case .roundFinished = $0 { return true }; if case .skipped = $0 { return true }; return false }.count,
            skipped: GameSession(events: events).skipCount, duration: GameSession(events: events).totalElapsedSeconds)
        copy.events = []
        return copy
    }

    var terminal: Bool { phase == .completed || phase == .ended }
    var round: Round { plan.activeRounds[step] }

    init(plan: GameSequence, authority: UUID, now: Date) throws {
        guard !plan.activeRounds.isEmpty, plan.activeRounds.allSatisfy({ $0.durationSeconds > 0 }),
              plan.roundCount > 0 else { throw CocoaError(.coderInvalidValue) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        self.version = 1
        self.id = UUID()
        self.authority = authority
        self.plan = plan
        self.planHash = SHA256.hash(data: try encoder.encode(plan)).map { String(format: "%02x", $0) }.joined()
        self.phase = plan.activeRounds[0].startPaused ? .waiting : .running
        self.anchor = phase == .running ? now : nil
        self.startedAt = now
        self.events = [.gameStarted(timestamp: now), .roundStarted(playerName: plan.activeRounds[0].name, emoji: plan.activeRounds[0].emoji, timestamp: now)]
    }

    func valid() -> Bool {
        guard version == 1, !plan.activeRounds.isEmpty,
              plan.activeRounds.indices.contains(step), repetition > 0,
              repetition <= plan.roundCount, elapsedBeforeRun.isFinite, elapsedBeforeRun >= 0,
              plan.activeRounds.allSatisfy({ $0.durationSeconds > 0 }) else { return false }
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(plan) else { return false }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() == planHash
    }

    func elapsed(at now: Date) -> TimeInterval {
        min(TimeInterval(round.durationSeconds), elapsedBeforeRun + (anchor.map { max(0, now.timeIntervalSince($0)) } ?? 0))
    }

    /// Reconciles one overdue step, preserving the existing wake semantics.
    @discardableResult
    mutating func reconcile(at now: Date) -> Bool {
        guard phase == .running, elapsed(at: now) >= Double(round.durationSeconds) else { return false }
        events.append(.roundFinished(playerName: round.name, timestamp: now))
        advance(at: now)
        revision += 1
        return true
    }

    mutating func apply(_ command: LiveRoutineCommand, at now: Date) -> Bool {
        if processed.contains(command.id) { return false }
        // Reconcile first. A command referring to the expired occurrence is rejected.
        reconcile(at: now)
        guard !terminal, command.session == id, command.revision == revision,
              command.occurrence == occurrence else { return false }
        processed.append(command.id)
        processed = Array(processed.suffix(32))
        switch command.action {
        case .pause:
            guard phase == .running else { return false }
            elapsedBeforeRun = elapsed(at: now); anchor = nil; phase = .paused
            events.append(.paused(timestamp: now))
        case .resume:
            guard phase == .paused || phase == .waiting else { return false }
            if phase == .paused { events.append(.resumed(timestamp: now)) }
            anchor = now; phase = .running
        case .next:
            events.append(.skipped(playerName: round.name, timestamp: now)); advance(at: now)
        case .restart:
            events.append(.restartTimer(playerName: round.name, timestamp: now)); enter(at: now)
        case .previous:
            guard step > 0 else { return false }
            step -= 1
            events.append(.doOver(previousPlayer: round.name, timestamp: now)); enter(at: now)
        case .end:
            phase = .ended; anchor = nil; events.append(.gameEnded(timestamp: now))
        }
        revision += 1
        return true
    }

    private mutating func advance(at now: Date) {
        if step + 1 < plan.activeRounds.count { step += 1; enter(at: now) }
        else if repetition < plan.roundCount { repetition += 1; step = 0; enter(at: now) }
        else { phase = .completed; anchor = nil; events.append(.gameEnded(timestamp: now)) }
    }

    private mutating func enter(at now: Date) {
        occurrence = UUID(); elapsedBeforeRun = 0
        phase = round.startPaused ? .waiting : .running
        anchor = phase == .running ? now : nil
        events.append(.roundStarted(playerName: round.name, emoji: round.emoji, timestamp: now))
    }
}

struct LiveRoutineCommand: Codable {
    enum Action: String, Codable { case pause, resume, next, restart, previous, end }
    var id = UUID()
    let session: UUID
    let revision: UInt64
    let occurrence: UUID
    let action: Action
}

/// One atomically persisted journal includes terminal sessions, preventing old
/// context deliveries from resurrecting an ended session after process death.
struct LiveRoutineJournal: Codable {
    var device = UUID()
    var current: LiveRoutineSession?
    var retired: Set<UUID> = []
    var conflict: LiveRoutineSession?
    var historyCommitted: Set<UUID> = []
    var endedOwned: [UUID] = []
    var joinedSession: UUID?
    var clockDate: Date?
    var clockContinuous: TimeInterval?
    var clockBoot: String?

    mutating func receive(_ incoming: LiveRoutineSession) -> Bool {
        guard incoming.valid(), !retired.contains(incoming.id) else { return false }
        if let current {
            if current.id == incoming.id {
                guard current.authority == incoming.authority, current.planHash == incoming.planHash,
                      incoming.revision > current.revision else { return false }
            } else if !current.terminal {
                if incoming.terminal {
                    retired.insert(incoming.id)
                    if conflict?.id == incoming.id { conflict = nil }
                } else if conflict?.id != incoming.id || incoming.revision > (conflict?.revision ?? 0) {
                    conflict = incoming
                }
                return false
            } else { retired.insert(current.id) }
        }
        // Following a successor preserves a join only when the previous
        // session was joined. Merely available routines stay unjoined.
        if let previous = current, previous.id != incoming.id, joinedSession == previous.id {
            joinedSession = incoming.id
        }
        current = incoming
        return true
    }
}

@MainActor
protocol LiveRoutineTransport: AnyObject {
    var receiveLive: ((Data) -> Void)? { get set }
    var receiveCommand: ((Data, @escaping (Data) -> Void) -> Void)? { get set }
    var connectionChanged: (() -> Void)? { get set }
    var reachable: Bool { get }
    func activate()
    func replayLiveContext()
    func publishLive(_ data: Data)
    func sendLiveCommand(_ data: Data, completion: @escaping (Data?) -> Void)
}

/// A monotonic clock controls an in-process run. Wall time is used only at
/// process startup, for persisted recovery and wire clock calibration.
struct RoutineClock {
    static var bootSession: String {
        var length = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &length, nil, 0) == 0, length > 0 else { return "" }
        var bytes = [CChar](repeating: 0, count: length)
        guard sysctlbyname("kern.bootsessionuuid", &bytes, &length, nil, 0) == 0 else { return "" }
        return String(cString: bytes)
    }
    var boot: () -> String = { RoutineClock.bootSession }
    var wall: () -> Date = Date.init
    var continuous: () -> TimeInterval = { Double(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / 1_000_000_000 }
}

@MainActor
final class LiveRoutineController {
    enum Result: String, Codable { case applied, duplicate, changed, terminal, notOwner, unavailable }
    struct Head: Codable { let id: UUID; let revision: UInt64 }
    struct Envelope: Codable {
        let head: Head?
        let state: LiveRoutineSession?
        let sentAt: Date
        let sender: UUID
        let ended: [UUID]
        var acknowledgement: UUID?
        var result: Result?
    }
    private(set) var journal: LiveRoutineJournal
    private var durableJournal: LiveRoutineJournal
    private(set) var storageHealthy = true
    private let url: URL
    private let transport: any LiveRoutineTransport
    private let clock: RoutineClock
    private let origin: Date
    private let originContinuous: TimeInterval
    var changed: (() -> Void)?
    var saveHistory: ((LiveRoutineSession) -> Bool)?
    var expired: (() -> Void)?
    private(set) var pending: UUID?
    private(set) var note: String?
    private(set) var lastSynced: Date?
    private(set) var uncertainty: TimeInterval?
    private var remoteSample: (date: Date, continuous: TimeInterval)?
    private var requiredRevision: UInt64 = 0
    private var frozenRemoteDate: Date?
    private var timeout: Task<Void, Never>?

    init(directory: URL? = nil, transport: any LiveRoutineTransport,
         clock: RoutineClock = RoutineClock()) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("LiveRoutine.json")
        let identityURL = base.appendingPathComponent("RoutineDeviceID")
        let decoded = try? JSONDecoder().decode(LiveRoutineJournal.self, from: Data(contentsOf: url))
        let identity = (try? String(contentsOf: identityURL, encoding: .utf8)).flatMap(UUID.init(uuidString:)) ?? decoded?.device ?? UUID()
        try? identity.uuidString.write(to: identityURL, atomically: true, encoding: .utf8)
        var loaded = decoded ?? LiveRoutineJournal(device: identity)
        if (decoded == nil && FileManager.default.fileExists(atPath: url.path)) || loaded.current?.valid() == false || loaded.conflict?.valid() == false {
            try? FileManager.default.moveItem(at: url, to: url.appendingPathExtension(UUID().uuidString + ".invalid"))
            loaded.current = nil; loaded.conflict = nil
        }
        loaded.device = identity
        journal = loaded; durableJournal = loaded
        self.transport = transport; self.clock = clock
        originContinuous = clock.continuous()
        if let savedDate = loaded.clockDate, let savedContinuous = loaded.clockContinuous,
           loaded.clockBoot == clock.boot(), !clock.boot().isEmpty, originContinuous >= savedContinuous {
            origin = savedDate.addingTimeInterval(originContinuous - savedContinuous)
        } else { origin = clock.wall() }
        transport.receiveLive = { [weak self] data in self?.receive(data) }
        transport.receiveCommand = { [weak self] data, reply in self?.command(data, reply: reply) }
        transport.connectionChanged = { [weak self] in
            self?.remoteSample = nil; self?.uncertainty = nil
            self?.changed?(); self?.handshake()
        }
    }

    var now: Date { origin.addingTimeInterval(max(0, clock.continuous() - originContinuous)) }
    var owner: Bool { journal.current?.authority == journal.device }
    var canControl: Bool { storageHealthy && (owner || (transport.reachable && pending == nil && uncertainty != nil && (journal.current?.revision ?? 0) >= requiredRevision && journal.conflict == nil)) }
    var isEstimating: Bool { !owner && remoteSample == nil }
    var renderDate: Date {
        if owner { return now }
        if let sample = remoteSample { return sample.date.addingTimeInterval(max(0, clock.continuous() - sample.continuous)) }
        return frozenRemoteDate ?? journal.current?.anchor ?? now
    }

    func activate() { transport.activate(); transport.replayLiveContext(); tick(); publish(); handshake() }

    func start(_ plan: GameSequence) {
        guard storageHealthy, journal.current?.terminal != false else { changed?(); return }
        if let old = journal.current { journal.retired.insert(old.id) }
        journal.current = try? LiveRoutineSession(plan: plan, authority: journal.device, now: now)
        journal.joinedSession = journal.current?.id
        note = nil; commit()
    }

    func dismiss() {
        guard journal.current?.terminal == true else { return }
        if let state = journal.current { journal.retired.insert(state.id) }
        journal.current = nil; journal.joinedSession = nil; commit()
    }

    /// A disconnected replica can leave locally, without ending its owner's run.
    func leave() {
        guard !owner, let state = journal.current else { return }
        journal.current = nil; journal.joinedSession = nil
        remoteSample = nil; uncertainty = nil; requiredRevision = 0; commit()
    }

    func join() { journal.joinedSession = journal.current?.id; commit() }

    func tick() {
        if !storageHealthy { _ = persist() }
        guard storageHealthy, owner, var state = journal.current else { return }
        if state.reconcile(at: now) {
            journal.current = state
            expired?()
            commit()
        }
    }

    func perform(_ action: LiveRoutineCommand.Action) {
        guard canControl, let state = journal.current, !state.terminal else { return }
        let command = LiveRoutineCommand(session: state.id, revision: state.revision, occurrence: state.occurrence, action: action)
        if owner { tick(); _ = apply(command); return }
        guard let data = try? JSONEncoder().encode(command) else { return }
        pending = command.id; note = nil; changed?()
        let sent = clock.continuous()
        timeout?.cancel()
        timeout = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, self?.pending == command.id else { return }
            self?.pending = nil; self?.note = Theme.LiveRoutine.noAcknowledgement; self?.changed?()
        }
        transport.sendLiveCommand(data) { [weak self] data in
            guard let self else { return }
            if let data { self.receive(data, roundTripStart: sent) }
            guard self.pending == command.id else { return }
            self.pending = nil; self.note = Theme.LiveRoutine.noAcknowledgement
            self.changed?()
        }
    }

    func useOtherSession() {
        guard let other = journal.conflict, !other.terminal, !journal.retired.contains(other.id) else { return }
        if owner {
            perform(.end)
            guard storageHealthy, journal.current?.terminal == true else {
                note = storageHealthy ? Theme.LiveRoutine.stepChanged : Theme.LiveRoutine.storageError
                changed?(); return
            }
        }
        if let old = journal.current { journal.retired.insert(old.id) }
        journal.current = other; journal.conflict = nil; journal.joinedSession = other.id
        remoteSample = nil; uncertainty = nil; requiredRevision = 0; commit(); handshake()
    }

    private func apply(_ command: LiveRoutineCommand) -> Result {
        guard owner, var state = journal.current else { return .notOwner }
        let wasDuplicate = state.processed.contains(command.id)
        let applied = state.apply(command, at: now)
        journal.current = state; commit()
        guard storageHealthy else { return .unavailable }
        if wasDuplicate { return .duplicate }
        return applied ? .applied : (state.terminal ? .terminal : .changed)
    }

    private func command(_ data: Data, reply: @escaping (Data) -> Void) {
        let command = try? JSONDecoder().decode(LiveRoutineCommand.self, from: data)
        tick()
        let result = command.map { apply($0) }
        reply(encoded(ack: command?.id, result: result, compact: true) ?? Data())
    }

    private func handshake() {
        guard transport.reachable else { return }
        let sent = clock.continuous()
        transport.sendLiveCommand(Data()) { [weak self] data in
            if let data { self?.receive(data, roundTripStart: sent) }
        }
    }

    private func receive(_ data: Data, roundTripStart: TimeInterval? = nil) {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
            note = Theme.LiveRoutine.versionMismatch; changed?(); return
        }
        if let state = envelope.state, !state.valid() { note = Theme.LiveRoutine.versionMismatch; changed?(); return }
        if let ack = envelope.acknowledgement, pending == ack {
            pending = nil; timeout?.cancel()
            note = envelope.result == .applied || envelope.result == .duplicate ? nil : Theme.LiveRoutine.stepChanged
        }
        if let conflict = journal.conflict, conflict.authority == envelope.sender, envelope.ended.contains(conflict.id) {
            journal.retired.insert(conflict.id); journal.conflict = nil
        }
        if let current = journal.current, current.authority == envelope.sender, envelope.ended.contains(current.id),
           envelope.state?.id != current.id {
            journal.retired.insert(current.id)
            journal.current?.phase = .ended; journal.current?.anchor = nil
        }
        if let state = envelope.state, state.valid(), state.authority == envelope.sender, state.authority != journal.device {
            let previousID = journal.current?.id
            let previousRevision = previousID == state.id ? journal.current?.revision ?? 0 : 0
            let adopted = journal.receive(state)
            if adopted && previousID != state.id {
                requiredRevision = 0
                remoteSample = nil; uncertainty = nil; frozenRemoteDate = nil
                if pending != nil { pending = nil; timeout?.cancel(); note = Theme.LiveRoutine.stepChanged }
            }
            if journal.current?.id == state.id && state.revision >= previousRevision &&
                (state.revision > previousRevision || frozenRemoteDate == nil || envelope.sentAt >= frozenRemoteDate!) {
                frozenRemoteDate = envelope.sentAt
                if let start = roundTripStart {
                    let duration = clock.continuous() - start
                    if duration >= 0 && duration <= 2 {
                        uncertainty = duration / 2
                        remoteSample = (envelope.sentAt.addingTimeInterval(duration / 2), clock.continuous())
                    } else { uncertainty = nil; remoteSample = nil }
                }
                lastSynced = clock.wall()
            }
        }
        if let current = journal.current, current.authority == envelope.sender, envelope.head?.id == current.id {
            requiredRevision = max(requiredRevision, envelope.head?.revision ?? 0)
            if let start = roundTripStart {
                let duration = clock.continuous() - start
                if duration >= 0 && duration <= 2 {
                    uncertainty = duration / 2
                    remoteSample = (envelope.sentAt.addingTimeInterval(duration / 2), clock.continuous())
                }
            }
        }
        persist(); changed?()
        if roundTripStart == nil, remoteSample == nil, journal.current?.authority == envelope.sender { handshake() }
    }

    private func encoded(ack: UUID? = nil, result: Result? = nil, compact: Bool = false) -> Data? {
        let state = owner ? journal.current?.wireSnapshot() : nil
        let head = state.map { Head(id: $0.id, revision: $0.revision) }
        let envelope = Envelope(head: head, state: state, sentAt: now, sender: journal.device,
            ended: Array(journal.endedOwned.suffix(16)), acknowledgement: ack, result: result)
        let data = try? JSONEncoder().encode(envelope)
        if compact, let data, data.count > 48_000 {
            return try? JSONEncoder().encode(Envelope(head: head, state: nil, sentAt: now, sender: journal.device,
                ended: Array(journal.endedOwned.suffix(16)), acknowledgement: ack, result: result))
        }
        return data
    }
    private func publish() { if let data = encoded() { transport.publishLive(data) } }
    @discardableResult
    private func persist() -> Bool {
        do {
            journal.clockDate = now; journal.clockContinuous = clock.continuous(); journal.clockBoot = clock.boot()
            try JSONEncoder().encode(journal).write(to: url, options: .atomic)
            durableJournal = journal; storageHealthy = true
            return true
        } catch {
            storageHealthy = false; note = Theme.LiveRoutine.storageError
            return false
        }
    }
    func commitHistoryIfNeeded() {
        guard owner, let state = journal.current, state.terminal,
              !journal.historyCommitted.contains(state.id), saveHistory?(state) == true else { return }
        journal.historyCommitted.insert(state.id); persist()
    }
    private func commit() {
        if owner, let state = journal.current, state.terminal, !journal.endedOwned.contains(state.id) {
            journal.endedOwned.append(state.id)
        }
        guard persist() else { journal = durableJournal; changed?(); return }
        commitHistoryIfNeeded(); changed?(); publish()
    }
}

/// Stateless shared presentation of synchronization choices.
struct LiveRoutineStatusView: View {
    let status: String?
    let conflict: Bool
    let replacement: String?
    let canReplace: Bool
    let available: Bool
    let replica: Bool
    let onJoin: () -> Void
    let onOther: () -> Void
    let onReplace: () -> Void
    let onCancel: () -> Void
    let onLeave: () -> Void

    var body: some View {
        VStack(spacing: Theme.Dimension.sectionSpacingSmall) {
            if let status { Text(status).font(.caption).foregroundStyle(Theme.ColorValue.textSecondary) }
            if available { Button(Theme.LiveRoutine.join, action: onJoin) }
            if conflict {
                Text(Theme.LiveRoutine.conflict).font(.caption)
                Button(Theme.LiveRoutine.useOther, action: onOther)
            }
            if let replacement {
                Button(Theme.LiveRoutine.replace(replacement), role: .destructive, action: onReplace)
                    .disabled(!canReplace)
                Button(Theme.LiveRoutine.keepCurrent, action: onCancel)
            }
            if replica { Button(Theme.LiveRoutine.leave, action: onLeave) }
        }
    }
}

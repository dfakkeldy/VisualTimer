import CloudKit
import Combine
import Foundation

@MainActor
final class TemplateCloudSyncEngine: ObservableObject, CKSyncEngineDelegate, @unchecked Sendable {
    enum SyncState: Equatable {
        case disabled
        case checkingAccount
        case idle
        case syncing
        case failed(String)
    }

    @Published private(set) var syncState: SyncState = .disabled
    @Published private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var changeRevision = 0

    private let configuration: TemplateSyncConfiguration
    private let templateLibrary: TemplateLibraryStore
    private let mapper: TemplateCloudRecordMapper
    private let userDefaults: UserDefaults
    private var syncEngine: CKSyncEngine?
    private var needsInitialTemplateSync = false
    private var inFlightRefreshTask: Task<Void, Never>?

    var statusText: String {
        switch syncState {
        case .disabled:
            return "Sync off"
        case .checkingAccount:
            return "Checking iCloud..."
        case .idle:
            if let lastSyncDate {
                return "Synced \(lastSyncDate.formatted(date: .omitted, time: .shortened))"
            }
            return "Sync ready"
        case .syncing:
            return "Syncing..."
        case .failed(let message):
            return message
        }
    }

    var statusSymbol: String {
        switch syncState {
        case .disabled:
            return "icloud.slash"
        case .checkingAccount, .syncing:
            return "icloud.and.arrow.up"
        case .idle:
            return "icloud"
        case .failed:
            return "exclamationmark.icloud"
        }
    }

    convenience init() {
        self.init(
            templateLibrary: TemplateLibraryStore(),
            configuration: TemplateSyncConfiguration()
        )
    }

    convenience init(templateLibrary: TemplateLibraryStore) {
        self.init(
            templateLibrary: templateLibrary,
            configuration: TemplateSyncConfiguration()
        )
    }

    init(
        templateLibrary: TemplateLibraryStore,
        configuration: TemplateSyncConfiguration,
        userDefaults: UserDefaults = .standard
    ) {
        self.templateLibrary = templateLibrary
        self.configuration = configuration
        self.userDefaults = userDefaults
        self.mapper = TemplateCloudRecordMapper(configuration: configuration)
    }

    func setEnabled(_ isEnabled: Bool) async {
        if isEnabled {
            await start()
        } else {
            stop()
        }
    }

    func queueLocalTemplates(_ templates: [SavedTemplate]) {
        guard let syncEngine else { return }
        let pendingChanges = templates.map { template in
            CKSyncEngine.PendingRecordZoneChange.saveRecord(mapper.recordID(for: template.id))
        }
        syncEngine.state.add(pendingRecordZoneChanges: pendingChanges)
    }

    func refreshNow() async {
        guard syncEngine != nil else { return }
        if let inFlightRefreshTask {
            await inFlightRefreshTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await performManualRefresh()
        }
        inFlightRefreshTask = task
        await task.value
        inFlightRefreshTask = nil
    }

    private func performManualRefresh() async {
        guard let syncEngine else { return }
        do {
            syncState = .syncing
            try await syncEngine.fetchChanges()
            try await syncEngine.sendChanges()
            lastSyncDate = Date()
            syncState = .idle
        } catch {
            syncState = .failed(CloudSyncError.from(error).localizedDescription)
        }
    }

    private func start() async {
        guard syncEngine == nil else {
            queueLocalTemplates(templateLibrary.listTemplates())
            return
        }

        syncState = .checkingAccount
        await refreshAccountStatus()
        guard accountStatus == .available else { return }

        var engineConfiguration = CKSyncEngine.Configuration(
            database: configuration.privateDatabase,
            stateSerialization: loadStateSerialization(),
            delegate: self
        )
        engineConfiguration.automaticallySync = true
        engineConfiguration.subscriptionID = TemplateSyncConfiguration.subscriptionID

        let engine = CKSyncEngine(engineConfiguration)
        syncEngine = engine
        needsInitialTemplateSync = true
        engine.state.add(pendingDatabaseChanges: [
            .saveZone(CKRecordZone(zoneID: configuration.zoneID)),
        ])
    }

    private func stop() {
        syncEngine = nil
        syncState = .disabled
    }

    private func refreshAccountStatus() async {
        do {
            let status = try await configuration.container.accountStatus()
            accountStatus = status
            switch status {
            case .available:
                syncState = .idle
            case .noAccount:
                syncState = .failed(CloudSyncError.accountUnavailable.localizedDescription)
            case .restricted:
                syncState = .failed(CloudSyncError.accountRestricted.localizedDescription)
            case .temporarilyUnavailable:
                syncState = .failed(CloudSyncError.accountTemporarilyUnavailable.localizedDescription)
            case .couldNotDetermine:
                syncState = .failed("Could not determine iCloud status.")
            @unknown default:
                syncState = .failed("Unknown iCloud status.")
            }
        } catch {
            syncState = .failed(CloudSyncError.from(error).localizedDescription)
        }
    }

    nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        await handleEventOnMainActor(event, syncEngine: syncEngine)
    }

    nonisolated func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pendingChanges = syncEngine.state.pendingRecordZoneChanges.filter {
            context.options.scope.contains($0)
        }
        return await makeRecordZoneChangeBatch(for: pendingChanges)
    }

    private func handleEventOnMainActor(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            saveStateSerialization(update.stateSerialization)
        case .accountChange:
            await refreshAccountStatus()
        case .fetchedRecordZoneChanges(let changes):
            applyFetchedRecordZoneChanges(changes)
        case .sentDatabaseChanges(let changes):
            let savedZoneChanges = changes.savedZones.map { CKSyncEngine.PendingDatabaseChange.saveZone($0) }
            syncEngine.state.remove(pendingDatabaseChanges: savedZoneChanges)
            if needsInitialTemplateSync,
               changes.savedZones.contains(where: { $0.zoneID == configuration.zoneID }) {
                needsInitialTemplateSync = false
                queueLocalTemplates(templateLibrary.listTemplates())
            }
        case .sentRecordZoneChanges(let changes):
            let savedChanges = changes.savedRecords.map { CKSyncEngine.PendingRecordZoneChange.saveRecord($0.recordID) }
            let deletedChanges = changes.deletedRecordIDs.map { CKSyncEngine.PendingRecordZoneChange.deleteRecord($0) }
            syncEngine.state.remove(pendingRecordZoneChanges: savedChanges + deletedChanges)
            if !changes.failedRecordSaves.isEmpty || !changes.failedRecordDeletes.isEmpty {
                syncState = .failed("Some templates did not sync.")
            }
        case .willFetchChanges, .willSendChanges:
            syncState = .syncing
        case .didFetchChanges, .didSendChanges:
            lastSyncDate = Date()
            syncState = .idle
        case .fetchedDatabaseChanges, .willFetchRecordZoneChanges, .didFetchRecordZoneChanges:
            break
        @unknown default:
            break
        }
    }

    private func makeRecordZoneChangeBatch(
        for pendingChanges: [CKSyncEngine.PendingRecordZoneChange]
    ) -> CKSyncEngine.RecordZoneChangeBatch? {
        guard !pendingChanges.isEmpty else { return nil }

        var recordsToSave: [CKRecord] = []
        var recordIDsToDelete: [CKRecord.ID] = []

        for change in pendingChanges {
            switch change {
            case .saveRecord(let recordID):
                guard let templateID = UUID(uuidString: recordID.recordName),
                      let document = try? templateLibrary.loadDocument(id: templateID),
                      let record = try? mapper.record(from: document)
                else { continue }
                recordsToSave.append(record)
            case .deleteRecord(let recordID):
                recordIDsToDelete.append(recordID)
            @unknown default:
                continue
            }
        }

        guard !recordsToSave.isEmpty || !recordIDsToDelete.isEmpty else { return nil }
        return CKSyncEngine.RecordZoneChangeBatch(
            recordsToSave: recordsToSave,
            recordIDsToDelete: recordIDsToDelete
        )
    }

    private func applyFetchedRecordZoneChanges(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges) {
        var appliedChanges = false

        for modification in changes.modifications {
            guard modification.record.recordType == TemplateSyncConfiguration.recordType else { continue }
            do {
                let incomingDocument = try mapper.document(from: modification.record)
                if let localDocument = try? templateLibrary.loadDocument(id: incomingDocument.templateID),
                   localDocument.modifiedAt > incomingDocument.modifiedAt {
                    queueLocalTemplates([
                        SavedTemplate(
                            id: localDocument.templateID,
                            title: localDocument.title,
                            roundCount: localDocument.game.rounds.count,
                            repeatCount: localDocument.game.roundCount,
                            totalSeconds: localDocument.game.activeRounds.reduce(0) { total, round in
                                total + round.durationSeconds
                            } * localDocument.game.roundCount,
                            modifiedAt: localDocument.modifiedAt,
                            url: URL(fileURLWithPath: "")
                        ),
                    ])
                    continue
                }
                _ = try templateLibrary.save(document: incomingDocument)
                appliedChanges = true
            } catch {
                syncState = .failed(CloudSyncError.from(error).localizedDescription)
            }
        }

        for deletion in changes.deletions where deletion.recordType == TemplateSyncConfiguration.recordType {
            guard let templateID = UUID(uuidString: deletion.recordID.recordName) else { continue }
            appliedChanges = applyRemoteTemplateDeletion(id: templateID) || appliedChanges
        }

        if appliedChanges {
            changeRevision += 1
        }
    }

    @discardableResult
    func applyRemoteTemplateDeletion(id templateID: UUID, lastSuccessfulSyncDate: Date? = nil) -> Bool {
        let syncDate = lastSuccessfulSyncDate ?? lastSyncDate
        if let localDocument = try? templateLibrary.loadDocument(id: templateID),
           shouldPreserveLocalChange(modifiedAt: localDocument.modifiedAt, lastSuccessfulSyncDate: syncDate) {
            queueLocalTemplateDocument(localDocument)
            return false
        }

        try? templateLibrary.deleteTemplate(id: templateID)
        return true
    }

    private func shouldPreserveLocalChange(modifiedAt: Date, lastSuccessfulSyncDate: Date?) -> Bool {
        guard let lastSuccessfulSyncDate else { return true }
        return modifiedAt > lastSuccessfulSyncDate
    }

    private func queueLocalTemplateDocument(_ document: TurnTimerTemplateDocument) {
        let game = document.game
        queueLocalTemplates([
            SavedTemplate(
                id: document.templateID,
                title: document.title,
                roundCount: game.activeRounds.count,
                repeatCount: game.roundCount,
                totalSeconds: game.activeRounds.reduce(0) { total, round in
                    total + round.durationSeconds
                } * game.roundCount,
                modifiedAt: document.modifiedAt,
                url: URL(fileURLWithPath: "")
            ),
        ])
    }

    private func saveStateSerialization(_ serialization: CKSyncEngine.State.Serialization) {
        do {
            let data = try JSONEncoder().encode(serialization)
            userDefaults.set(data, forKey: TemplateSyncConfiguration.stateSerializationKey)
        } catch {
            syncState = .failed("Could not save sync state.")
        }
    }

    private func loadStateSerialization() -> CKSyncEngine.State.Serialization? {
        guard let data = userDefaults.data(forKey: TemplateSyncConfiguration.stateSerializationKey) else {
            return nil
        }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }
}

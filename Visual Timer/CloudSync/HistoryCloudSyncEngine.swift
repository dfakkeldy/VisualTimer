import CloudKit
import Combine
import Foundation

@MainActor
final class HistoryCloudSyncEngine: ObservableObject, CKSyncEngineDelegate, @unchecked Sendable {
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

    private let configuration: HistorySyncConfiguration
    private let historyStore: HistoryStore
    private let mapper: HistoryCloudRecordMapper
    private let userDefaults: UserDefaults
    private var syncEngine: CKSyncEngine?
    private var needsInitialHistorySync = false
    private var pendingDeletedHistoryIDs = Set<UUID>()
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

    convenience init() {
        self.init(historyStore: HistoryStore(), configuration: HistorySyncConfiguration())
    }

    convenience init(historyStore: HistoryStore) {
        self.init(historyStore: historyStore, configuration: HistorySyncConfiguration())
    }

    init(
        historyStore: HistoryStore,
        configuration: HistorySyncConfiguration,
        userDefaults: UserDefaults = .standard
    ) {
        self.historyStore = historyStore
        self.configuration = configuration
        self.userDefaults = userDefaults
        self.mapper = HistoryCloudRecordMapper(configuration: configuration)
        self.pendingDeletedHistoryIDs = Self.loadPendingDeletedHistoryIDs(from: userDefaults)
    }

    func setEnabled(_ isEnabled: Bool) async {
        if isEnabled {
            await start()
        } else {
            stop()
        }
    }

    func queueLocalHistory(_ records: [GameRecord]) {
        guard let syncEngine else { return }
        let pendingChanges = records
            .filter { !pendingDeletedHistoryIDs.contains($0.id) }
            .map { record in
                CKSyncEngine.PendingRecordZoneChange.saveRecord(mapper.recordID(for: record.id))
            }
        syncEngine.state.add(pendingRecordZoneChanges: pendingChanges)
    }

    func queueDeletedHistory(id: UUID) {
        pendingDeletedHistoryIDs.insert(id)
        savePendingDeletedHistoryIDs()
        guard syncEngine != nil, !needsInitialHistorySync else { return }
        queuePendingDeletedHistories()
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
            queueLocalHistory(historyStore.loadAll())
            queuePendingDeletedHistories()
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
        engineConfiguration.subscriptionID = HistorySyncConfiguration.subscriptionID

        let engine = CKSyncEngine(engineConfiguration)
        syncEngine = engine
        needsInitialHistorySync = true
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
            if needsInitialHistorySync,
               changes.savedZones.contains(where: { $0.zoneID == configuration.zoneID }) {
                needsInitialHistorySync = false
                queuePendingDeletedHistories()
                queueLocalHistory(historyStore.loadAll())
            }
        case .sentRecordZoneChanges(let changes):
            let savedChanges = changes.savedRecords.map { CKSyncEngine.PendingRecordZoneChange.saveRecord($0.recordID) }
            let deleteResult = handleSentDeletedRecordResults(
                deletedRecordIDs: changes.deletedRecordIDs,
                failedRecordDeletes: changes.failedRecordDeletes
            )
            let deletedChanges = deleteResult.confirmedRecordIDs.map {
                CKSyncEngine.PendingRecordZoneChange.deleteRecord($0)
            }
            syncEngine.state.remove(pendingRecordZoneChanges: savedChanges + deletedChanges)
            if !changes.failedRecordSaves.isEmpty || deleteResult.hasRetryableFailures {
                syncState = .failed("Some history did not sync.")
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
                guard let historyID = UUID(uuidString: recordID.recordName),
                      let document = historyStore.loadDocument(id: historyID),
                      let cloudRecord = try? mapper.record(from: document)
                else { continue }
                recordsToSave.append(cloudRecord)
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
            guard modification.record.recordType == HistorySyncConfiguration.recordType else { continue }
            do {
                let incomingDocument = try mapper.document(from: modification.record)
                appliedChanges = applyFetchedHistoryDocument(incomingDocument) || appliedChanges
            } catch {
                syncState = .failed(CloudSyncError.from(error).localizedDescription)
            }
        }

        for deletion in changes.deletions where deletion.recordType == HistorySyncConfiguration.recordType {
            guard let historyID = UUID(uuidString: deletion.recordID.recordName) else { continue }
            appliedChanges = applyRemoteHistoryDeletion(id: historyID) || appliedChanges
        }

        if appliedChanges {
            changeRevision += 1
        }
    }

    @discardableResult
    func applyFetchedHistoryDocument(_ incomingDocument: HistoryDocument) -> Bool {
        let historyID = incomingDocument.record.id
        if pendingDeletedHistoryIDs.contains(historyID) {
            historyStore.delete(id: historyID)
            queuePendingDeletedHistories()
            return true
        }

        if let localDocument = historyStore.loadDocument(id: historyID),
           localDocument.modifiedAt > incomingDocument.modifiedAt {
            queueLocalHistory([localDocument.record])
            return false
        }

        historyStore.save(document: incomingDocument)
        return true
    }

    @discardableResult
    func applyRemoteHistoryDeletion(id historyID: UUID, lastSuccessfulSyncDate: Date? = nil) -> Bool {
        let recordID = mapper.recordID(for: historyID)
        if pendingDeletedHistoryIDs.contains(historyID) {
            historyStore.delete(id: historyID)
            removeConfirmedDeletedHistoryIDs([recordID])
            return true
        }

        let syncDate = lastSuccessfulSyncDate ?? lastSyncDate
        if let localDocument = historyStore.loadDocument(id: historyID),
           shouldPreserveLocalChange(modifiedAt: localDocument.modifiedAt, lastSuccessfulSyncDate: syncDate) {
            queueLocalHistory([localDocument.record])
            return false
        }

        historyStore.delete(id: historyID)
        removeConfirmedDeletedHistoryIDs([recordID])
        return true
    }

    @discardableResult
    func handleSentDeletedRecordResults(
        deletedRecordIDs: [CKRecord.ID],
        failedRecordDeletes: [CKRecord.ID: CKError]
    ) -> (confirmedRecordIDs: [CKRecord.ID], hasRetryableFailures: Bool) {
        let unknownItemRecordIDs = failedRecordDeletes.compactMap { recordID, error in
            error.code == .unknownItem ? recordID : nil
        }
        let confirmedRecordIDs = deletedRecordIDs + unknownItemRecordIDs
        removeConfirmedDeletedHistoryIDs(confirmedRecordIDs)

        let hasRetryableFailures = failedRecordDeletes.contains { _, error in
            error.code != .unknownItem
        }
        return (confirmedRecordIDs, hasRetryableFailures)
    }

    private func queuePendingDeletedHistories() {
        guard let syncEngine, !pendingDeletedHistoryIDs.isEmpty else { return }
        let pendingChanges = pendingDeletedHistoryIDs.map { historyID in
            CKSyncEngine.PendingRecordZoneChange.deleteRecord(mapper.recordID(for: historyID))
        }
        syncEngine.state.add(pendingRecordZoneChanges: pendingChanges)
    }

    private func shouldPreserveLocalChange(modifiedAt: Date, lastSuccessfulSyncDate: Date?) -> Bool {
        guard let lastSuccessfulSyncDate else { return true }
        return modifiedAt > lastSuccessfulSyncDate
    }

    private func removeConfirmedDeletedHistoryIDs(_ recordIDs: [CKRecord.ID]) {
        let confirmedIDs = Set(recordIDs.compactMap { UUID(uuidString: $0.recordName) })
        guard !confirmedIDs.isEmpty else { return }
        pendingDeletedHistoryIDs.subtract(confirmedIDs)
        savePendingDeletedHistoryIDs()
    }

    private func savePendingDeletedHistoryIDs() {
        let ids = pendingDeletedHistoryIDs
            .map(\.uuidString)
            .sorted()
        userDefaults.set(ids, forKey: HistorySyncConfiguration.pendingDeletedHistoryIDsKey)
    }

    private static func loadPendingDeletedHistoryIDs(from userDefaults: UserDefaults) -> Set<UUID> {
        let strings = userDefaults.stringArray(forKey: HistorySyncConfiguration.pendingDeletedHistoryIDsKey) ?? []
        return Set(strings.compactMap(UUID.init(uuidString:)))
    }

    private func saveStateSerialization(_ serialization: CKSyncEngine.State.Serialization) {
        do {
            let data = try JSONEncoder().encode(serialization)
            userDefaults.set(data, forKey: HistorySyncConfiguration.stateSerializationKey)
        } catch {
            syncState = .failed("Could not save sync state.")
        }
    }

    private func loadStateSerialization() -> CKSyncEngine.State.Serialization? {
        guard let data = userDefaults.data(forKey: HistorySyncConfiguration.stateSerializationKey) else {
            return nil
        }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }
}

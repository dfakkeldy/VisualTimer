import CloudKit
import Foundation

struct CloudKitValidationRunner {
    struct Operations {
        var accountStatus: () async throws -> CKAccountStatus
        var saveZone: (CKRecordZone.ID) async throws -> Void
        var saveFetchDeleteRecord: (CKRecord) async throws -> Void
    }

    private let templateConfiguration: TemplateSyncConfiguration
    private let historyConfiguration: HistorySyncConfiguration
    private let templateMapper: TemplateCloudRecordMapper
    private let historyMapper: HistoryCloudRecordMapper
    private let operations: Operations

    init(
        templateConfiguration: TemplateSyncConfiguration = TemplateSyncConfiguration(),
        historyConfiguration: HistorySyncConfiguration = HistorySyncConfiguration(),
        operations: Operations? = nil
    ) {
        self.templateConfiguration = templateConfiguration
        self.historyConfiguration = historyConfiguration
        self.templateMapper = TemplateCloudRecordMapper(configuration: templateConfiguration)
        self.historyMapper = HistoryCloudRecordMapper(configuration: historyConfiguration)
        if let operations {
            self.operations = operations
        } else {
            let database = templateConfiguration.privateDatabase
            self.operations = Operations(
                accountStatus: {
                    try await templateConfiguration.container.accountStatus()
                },
                saveZone: { zoneID in
                    _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
                },
                saveFetchDeleteRecord: { record in
                    let saved = try await database.save(record)
                    _ = try await database.record(for: saved.recordID)
                    try await database.deleteRecord(withID: saved.recordID)
                }
            )
        }
    }

    func run() async -> CloudKitValidationReport {
        var checks: [CloudKitValidationReport.Check] = []

        do {
            let status = try await operations.accountStatus()
            if status == .available {
                checks.append(.init(name: "iCloud account", status: .passed, detail: "CloudKit account is available."))
            } else {
                checks.append(.init(name: "iCloud account", status: .failed, detail: "CloudKit account status is \(status)."))
                return CloudKitValidationReport(checks: checks)
            }
        } catch {
            checks.append(.init(name: "iCloud account", status: .failed, detail: error.localizedDescription))
            return CloudKitValidationReport(checks: checks)
        }

        do {
            try await operations.saveZone(templateConfiguration.zoneID)
            checks.append(.init(name: "Template zone", status: .passed, detail: "Zone \(TemplateSyncConfiguration.zoneName) can be saved."))
        } catch {
            checks.append(.init(name: "Template zone", status: .failed, detail: error.localizedDescription))
            return CloudKitValidationReport(checks: checks)
        }

        do {
            try await operations.saveZone(historyConfiguration.zoneID)
            checks.append(.init(name: "History zone", status: .passed, detail: "Zone \(HistorySyncConfiguration.zoneName) can be saved."))
        } catch {
            checks.append(.init(name: "History zone", status: .failed, detail: error.localizedDescription))
            return CloudKitValidationReport(checks: checks)
        }

        do {
            let document = TurnTimerTemplateDocument(
                title: "CloudKit Validation Probe",
                game: StarterTemplateLibrary.defaultTemplate.game
            )
            let record = try templateMapper.record(from: document)
            try await operations.saveFetchDeleteRecord(record)
            checks.append(.init(name: "Template schema", status: .passed, detail: "Template record save, fetch, and delete succeeded."))
        } catch {
            checks.append(.init(name: "Template schema", status: .failed, detail: error.localizedDescription))
        }

        do {
            let record = GameRecord(
                id: UUID(),
                gameTitle: "CloudKit History Validation Probe",
                session: GameSession(events: []),
                playerNames: [],
                playedAt: Date()
            )
            let document = HistoryDocument(record: record)
            let cloudRecord = try historyMapper.record(from: document)
            try await operations.saveFetchDeleteRecord(cloudRecord)
            checks.append(.init(name: "History schema", status: .passed, detail: "History record save, fetch, and delete succeeded."))
        } catch {
            checks.append(.init(name: "History schema", status: .failed, detail: error.localizedDescription))
        }

        checks.append(.init(
            name: "Production schema",
            status: .warning,
            detail: "Confirm CloudKit Dashboard development schema is deployed to production before App Store submission."
        ))

        return CloudKitValidationReport(checks: checks)
    }
}

import CloudKit
import Foundation

struct CloudKitValidationRunner {
    private let configuration: TemplateSyncConfiguration
    private let mapper: TemplateCloudRecordMapper
    private let database: CKDatabase

    init(configuration: TemplateSyncConfiguration = TemplateSyncConfiguration()) {
        self.configuration = configuration
        self.mapper = TemplateCloudRecordMapper(configuration: configuration)
        self.database = configuration.privateDatabase
    }

    func run() async -> CloudKitValidationReport {
        var checks: [CloudKitValidationReport.Check] = []

        do {
            let status = try await configuration.container.accountStatus()
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
            _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: configuration.zoneID)], deleting: [])
            checks.append(.init(name: "Template zone", status: .passed, detail: "Zone \(TemplateSyncConfiguration.zoneName) can be saved."))
        } catch {
            checks.append(.init(name: "Template zone", status: .failed, detail: error.localizedDescription))
            return CloudKitValidationReport(checks: checks)
        }

        do {
            let document = TurnTimerTemplateDocument(
                title: "CloudKit Validation Probe",
                game: StarterTemplateLibrary.defaultTemplate.game
            )
            let record = try mapper.record(from: document)
            let saved = try await database.save(record)
            _ = try await database.record(for: saved.recordID)
            try await database.deleteRecord(withID: saved.recordID)
            checks.append(.init(name: "Template schema", status: .passed, detail: "Template record save, fetch, and delete succeeded."))
        } catch {
            checks.append(.init(name: "Template schema", status: .failed, detail: error.localizedDescription))
        }

        checks.append(.init(
            name: "Production schema",
            status: .warning,
            detail: "Confirm CloudKit Dashboard development schema is deployed to production before App Store submission."
        ))

        return CloudKitValidationReport(checks: checks)
    }
}

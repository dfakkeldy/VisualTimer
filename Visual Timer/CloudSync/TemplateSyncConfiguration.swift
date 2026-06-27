import CloudKit
import Foundation

struct TemplateSyncConfiguration {
    static let containerIdentifier = "iCloud.Dan.Visual-Timer"
    static let zoneName = "TurnTimerTemplates"
    static let recordType = "Template"
    static let subscriptionID = "turntimer-template-sync"
    static let stateSerializationKey = "turntimer.templateSync.stateSerialization"

    let containerIdentifier: String

    init(containerIdentifier: String = Self.containerIdentifier) {
        self.containerIdentifier = containerIdentifier
    }

    var container: CKContainer {
        CKContainer(identifier: containerIdentifier)
    }

    var privateDatabase: CKDatabase {
        container.privateCloudDatabase
    }

    var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
    }
}

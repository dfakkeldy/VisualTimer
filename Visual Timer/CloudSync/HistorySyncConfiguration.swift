import CloudKit
import Foundation

struct HistorySyncConfiguration {
    static let containerIdentifier = TemplateSyncConfiguration.containerIdentifier
    static let zoneName = "TurnTimerHistory"
    static let recordType = "HistoryRecord"
    static let subscriptionID = "turntimer-history-sync"
    static let stateSerializationKey = "turntimer.historySync.stateSerialization"

    let container: CKContainer
    let zoneID: CKRecordZone.ID

    init(container: CKContainer = CKContainer(identifier: Self.containerIdentifier)) {
        self.container = container
        self.zoneID = CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    var privateDatabase: CKDatabase {
        container.privateCloudDatabase
    }
}

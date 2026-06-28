import CloudKit
import Foundation

struct HistorySyncConfiguration {
    static let containerIdentifier = TemplateSyncConfiguration.containerIdentifier
    static let zoneName = "TurnTimerHistory"
    static let recordType = "HistoryRecord"
    static let subscriptionID = "turntimer-history-sync"
    static let stateSerializationKey = "turntimer.historySync.stateSerialization"
    static let pendingDeletedHistoryIDsKey = "turntimer.historySync.pendingDeletedHistoryIDs"

    let containerIdentifier: String

    init(containerIdentifier: String = Self.containerIdentifier) {
        self.containerIdentifier = containerIdentifier
    }

    var container: CKContainer {
        CKContainer(identifier: containerIdentifier)
    }

    var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    var privateDatabase: CKDatabase {
        container.privateCloudDatabase
    }
}

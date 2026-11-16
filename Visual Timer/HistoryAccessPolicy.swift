import Foundation

enum HistoryAccessPolicy {
    static let freeRecordLimit = 5

    static func visibleRecords<Record>(_ records: [Record], isProUnlocked: Bool) -> [Record] {
        guard !isProUnlocked else { return records }
        return Array(records.prefix(freeRecordLimit))
    }

    static func isLimited(records: [GameRecord], isProUnlocked: Bool) -> Bool {
        !isProUnlocked && records.count > freeRecordLimit
    }
}

import Foundation

enum HistoryAccessPolicy {
    static let freeRecordLimit = 5

    static func visibleRecords(_ records: [GameRecord], isProUnlocked: Bool) -> [GameRecord] {
        guard !isProUnlocked else { return records }
        return Array(records.prefix(freeRecordLimit))
    }

    static func isLimited(records: [GameRecord], isProUnlocked: Bool) -> Bool {
        !isProUnlocked && records.count > freeRecordLimit
    }
}

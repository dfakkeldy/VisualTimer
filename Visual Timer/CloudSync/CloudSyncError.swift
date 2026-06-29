import CloudKit
import Foundation

enum CloudSyncError: LocalizedError {
    case accountUnavailable
    case accountRestricted
    case accountTemporarilyUnavailable
    case networkUnavailable
    case quotaExceeded
    case zoneNotFound
    case unknownRecordType(String)
    case recordIDMismatch(recordName: String, payloadID: String)
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .accountUnavailable:
            return "iCloud is not signed in."
        case .accountRestricted:
            return "iCloud is restricted on this device."
        case .accountTemporarilyUnavailable:
            return "iCloud is temporarily unavailable."
        case .networkUnavailable:
            return "Network unavailable. Changes will sync later."
        case .quotaExceeded:
            return "iCloud storage is full."
        case .zoneNotFound:
            return "Cloud sync zone was not found."
        case .unknownRecordType(let recordType):
            return "Unknown CloudKit record type: \(recordType)."
        case .recordIDMismatch(let recordName, let payloadID):
            return "CloudKit record ID \(recordName) does not match payload ID \(payloadID)."
        case .syncFailed(let message):
            return message
        }
    }

    static func from(_ error: Error) -> CloudSyncError {
        guard let ckError = error as? CKError else {
            return .syncFailed(error.localizedDescription)
        }

        switch ckError.code {
        case .notAuthenticated:
            return .accountUnavailable
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
        case .quotaExceeded:
            return .quotaExceeded
        case .zoneNotFound:
            return .zoneNotFound
        case .serviceUnavailable:
            return .accountTemporarilyUnavailable
        default:
            return .syncFailed(ckError.localizedDescription)
        }
    }
}

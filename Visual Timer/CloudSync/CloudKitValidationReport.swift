import Foundation

struct CloudKitValidationReport: Equatable {
    enum Status: Equatable {
        case passed
        case warning
        case failed
    }

    struct Check: Equatable {
        var name: String
        var status: Status
        var detail: String
    }

    var generatedAt: Date
    var checks: [Check]

    init(generatedAt: Date = Date(), checks: [Check]) {
        self.generatedAt = generatedAt
        self.checks = checks
    }

    var failedChecks: [Check] {
        checks.filter { $0.status == .failed }
    }

    var warningChecks: [Check] {
        checks.filter { $0.status == .warning }
    }

    var isReadyForRelease: Bool {
        failedChecks.isEmpty && warningChecks.isEmpty
    }
}

import XCTest

/// Shared by Watch UI checks and their condition-wait regression tests.
@MainActor
enum PredicateWait {
    static func matches(_ predicate: NSPredicate, object: Any?, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: object)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}

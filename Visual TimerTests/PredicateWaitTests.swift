import Foundation
import Testing

@Suite(.serialized)
@MainActor
struct PredicateWaitTests {
    @Test
    func acceptsAnImmediateMatch() {
        #expect(PredicateWait.matches(NSPredicate(value: true), object: nil, timeout: 2.5))
    }

    @Test
    func rejectsAConditionThatNeverMatches() {
        #expect(!PredicateWait.matches(NSPredicate(value: false), object: nil, timeout: 0.05))
    }

    @Test
    func acceptsAMatchingReadThatReturnsAcrossTheWaitDeadline() {
        // XCTest's first predicate poll is one second into the archived wait.
        // Leave time for that poll to start, then return the read after expiry.
        let label = DelayedLabel(value: "Start", delay: 3)
        let predicate = NSPredicate(format: "label == %@", "Start")
        #expect(PredicateWait.matches(predicate, object: label, timeout: 2.5))
    }
}

/// Models the synchronous accessibility query made by XCUIElement.label.
private final class DelayedLabel: NSObject {
    let value: String
    let delay: TimeInterval

    init(value: String, delay: TimeInterval) {
        self.value = value
        self.delay = delay
    }

    @objc var label: String {
        Thread.sleep(forTimeInterval: delay)
        return value
    }
}

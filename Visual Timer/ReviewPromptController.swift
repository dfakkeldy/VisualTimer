import Combine
import Foundation

@MainActor
final class ReviewPromptController: ObservableObject {

    private enum Constants {
        static let minimumCompletedSessions = 2
    }

    private enum Key {
        static let completedSessionCount = "turnTimer.reviewPrompt.completedSessionCount"
        static let hasRequestedReview = "turnTimer.reviewPrompt.hasRequestedReview"
        static let lastRequestDate = "turnTimer.reviewPrompt.lastRequestDate"
    }

    private let userDefaults: UserDefaults
    private let now: () -> Date

    init(
        userDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.userDefaults = userDefaults
        self.now = now
    }

    func recordCompletedSessionAndShouldRequestReview() -> Bool {
        let completedSessionCount = userDefaults.integer(forKey: Key.completedSessionCount) + 1
        userDefaults.set(completedSessionCount, forKey: Key.completedSessionCount)

        guard completedSessionCount >= Constants.minimumCompletedSessions,
              !userDefaults.bool(forKey: Key.hasRequestedReview)
        else {
            return false
        }

        userDefaults.set(true, forKey: Key.hasRequestedReview)
        userDefaults.set(now(), forKey: Key.lastRequestDate)
        return true
    }
}

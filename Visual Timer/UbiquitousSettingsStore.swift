import Combine
import Foundation

@MainActor
final class UbiquitousSettingsStore: ObservableObject, @unchecked Sendable {
    @Published private(set) var selectedSound: TimerSound?

    private enum Key {
        static let selectedSound = "turntimer.selectedSound"
    }

    private let store: NSUbiquitousKeyValueStore
    private var observer: NSObjectProtocol?

    init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
        selectedSound = Self.readSelectedSound(from: store)
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.selectedSound = Self.readSelectedSound(from: self.store)
            }
        }
        store.synchronize()
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func updateSelectedSound(_ sound: TimerSound) {
        guard selectedSound != sound else { return }
        selectedSound = sound
        store.set(sound.rawValue, forKey: Key.selectedSound)
        store.synchronize()
    }

    private static func readSelectedSound(from store: NSUbiquitousKeyValueStore) -> TimerSound? {
        guard let rawValue = store.string(forKey: Key.selectedSound) else { return nil }
        return TimerSound(rawValue: rawValue)
    }
}

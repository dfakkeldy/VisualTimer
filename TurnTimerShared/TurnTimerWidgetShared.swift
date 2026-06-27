import Foundation

enum TurnTimerSharedConstants {
    static let appGroupIdentifier = "group.Dan.Visual-Timer"
    static let widgetKind = "TurnTimerTemplateWidget"
}

struct TemplateWidgetSnapshot: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let roundCount: Int
    let repeatCount: Int
    let firstRoundName: String
    let firstRoundDurationSeconds: Int
    let totalDurationSeconds: Int
    let modifiedAt: Date
}

struct TemplateWidgetPayload: Codable, Equatable {
    var favoriteTemplateID: String?
    var templates: [TemplateWidgetSnapshot]
    var generatedAt: Date

    static let empty = TemplateWidgetPayload(
        favoriteTemplateID: nil,
        templates: [],
        generatedAt: Date(timeIntervalSince1970: 0)
    )

    var favoriteTemplate: TemplateWidgetSnapshot? {
        guard let favoriteTemplateID else { return templates.first }
        return templates.first { $0.id == favoriteTemplateID } ?? templates.first
    }
}

struct TemplateWidgetStore {
    private enum Key {
        static let payload = "turntimer.widget.payload"
        static let pendingStartTemplateID = "turntimer.widget.pendingStartTemplateID"
        static let pendingOpenTemplates = "turntimer.widget.pendingOpenTemplates"
    }

    private let userDefaults: UserDefaults?

    init(userDefaults: UserDefaults? = UserDefaults(suiteName: TurnTimerSharedConstants.appGroupIdentifier)) {
        self.userDefaults = userDefaults
    }

    func readPayload() -> TemplateWidgetPayload {
        guard let data = userDefaults?.data(forKey: Key.payload),
              let payload = try? JSONDecoder().decode(TemplateWidgetPayload.self, from: data)
        else {
            return .empty
        }
        return payload
    }

    func writePayload(_ payload: TemplateWidgetPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        userDefaults?.set(data, forKey: Key.payload)
    }

    func writePendingStart(templateID: String) {
        userDefaults?.set(templateID, forKey: Key.pendingStartTemplateID)
    }

    func consumePendingStartTemplateID() -> String? {
        let templateID = userDefaults?.string(forKey: Key.pendingStartTemplateID)
        userDefaults?.removeObject(forKey: Key.pendingStartTemplateID)
        return templateID
    }

    func writePendingOpenTemplates() {
        userDefaults?.set(true, forKey: Key.pendingOpenTemplates)
    }

    func consumePendingOpenTemplates() -> Bool {
        let shouldOpen = userDefaults?.bool(forKey: Key.pendingOpenTemplates) ?? false
        userDefaults?.removeObject(forKey: Key.pendingOpenTemplates)
        return shouldOpen
    }
}

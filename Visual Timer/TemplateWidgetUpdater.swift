import Combine
import Foundation
import WidgetKit

@MainActor
final class FavoriteTemplateStore: ObservableObject {
    @Published private(set) var favoriteTemplateID: String?

    private enum Key {
        static let favoriteTemplateID = "turntimer.favoriteTemplateID"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        favoriteTemplateID = userDefaults.string(forKey: Key.favoriteTemplateID)
    }

    func isFavorite(_ template: SavedTemplate) -> Bool {
        favoriteTemplateID == template.id.uuidString
    }

    func toggleFavorite(_ template: SavedTemplate) {
        if isFavorite(template) {
            favoriteTemplateID = nil
            userDefaults.removeObject(forKey: Key.favoriteTemplateID)
        } else {
            favoriteTemplateID = template.id.uuidString
            userDefaults.set(template.id.uuidString, forKey: Key.favoriteTemplateID)
        }
    }

    func removeMissingFavorite(from templates: [SavedTemplate]) {
        guard let favoriteTemplateID,
              !templates.contains(where: { $0.id.uuidString == favoriteTemplateID })
        else { return }
        self.favoriteTemplateID = nil
        userDefaults.removeObject(forKey: Key.favoriteTemplateID)
    }
}

struct TemplateWidgetUpdater {
    let templateLibrary: TemplateLibraryStore
    let widgetStore: TemplateWidgetStore

    init(
        templateLibrary: TemplateLibraryStore,
        widgetStore: TemplateWidgetStore = TemplateWidgetStore()
    ) {
        self.templateLibrary = templateLibrary
        self.widgetStore = widgetStore
    }

    func refresh(savedTemplates: [SavedTemplate], favoriteTemplateID: String?) {
        let snapshots = savedTemplates.compactMap { try? templateLibrary.snapshot(for: $0) }
        let payload = TemplateWidgetPayload(
            favoriteTemplateID: favoriteTemplateID,
            templates: snapshots,
            generatedAt: Date()
        )
        widgetStore.writePayload(payload)
        WidgetCenter.shared.reloadTimelines(ofKind: TurnTimerSharedConstants.widgetKind)
    }
}

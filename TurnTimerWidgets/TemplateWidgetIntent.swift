import AppIntents
import Foundation

struct TemplateWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Template"
    static var description = IntentDescription("Choose the template this widget starts.")

    @Parameter(title: "Template")
    var template: TemplateWidgetTemplate?

    init() {
        template = nil
    }

    init(template: TemplateWidgetTemplate?) {
        self.template = template
    }
}

struct TemplateWidgetTemplate: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Template"
    static var defaultQuery = TemplateWidgetTemplateQuery()

    let id: String
    let title: String
    let subtitle: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
    }

    init(snapshot: WidgetTemplateSnapshot) {
        id = snapshot.id
        title = snapshot.title
        subtitle = snapshot.subtitle
    }
}

struct TemplateWidgetTemplateQuery: EntityQuery {
    func entities(for identifiers: [TemplateWidgetTemplate.ID]) async throws -> [TemplateWidgetTemplate] {
        options().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [TemplateWidgetTemplate] {
        options()
    }

    func defaultResult() async -> TemplateWidgetTemplate? {
        options().first { $0.id == "game-night" } ?? options().first
    }

    private func options() -> [TemplateWidgetTemplate] {
        let snapshots = WidgetTemplateSnapshot.selectableSnapshots(
            from: TemplateStartTimelineProvider.availableSnapshots()
        )
        return snapshots.map(TemplateWidgetTemplate.init(snapshot:))
    }
}

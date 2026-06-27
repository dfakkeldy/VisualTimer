import AppIntents
import Foundation

struct StartFavoriteTemplateIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Favorite Timer"
    static var description = IntentDescription("Open Turn Timer and start the selected favorite template.")
    static var openAppWhenRun = true
    static var isDiscoverable = false

    @Parameter(title: "Template ID")
    var templateID: String

    init() {
        templateID = ""
    }

    init(templateID: String) {
        self.templateID = templateID
    }

    func perform() async throws -> some IntentResult {
        guard !templateID.isEmpty else { return .result() }
        TemplateWidgetStore().writePendingStart(templateID: templateID)
        return .result()
    }
}

struct OpenTemplatesIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Templates"
    static var description = IntentDescription("Open Turn Timer to choose a favorite template.")
    static var openAppWhenRun = true
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        TemplateWidgetStore().writePendingOpenTemplates()
        return .result()
    }
}

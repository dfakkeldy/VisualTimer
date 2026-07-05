import SwiftUI
import WidgetKit

struct TemplateStartWidget: Widget {
    static let kind = "TemplateStartWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: TemplateWidgetIntent.self,
            provider: TemplateStartTimelineProvider()
        ) { entry in
            TemplateStartWidgetView(entry: entry)
        }
        .configurationDisplayName("Turn Timer")
        .description("Start a saved or starter template.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

import AppIntents
import SwiftUI
import WidgetKit

struct TurnTimerTemplateWidget: Widget {
    let kind = TurnTimerSharedConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TemplateProvider()) { entry in
            TemplateWidgetView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Favorite Timer")
        .description("Start a favorite Turn Timer template from your Home Screen or Lock Screen.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

struct TemplateEntry: TimelineEntry {
    let date: Date
    let payload: TemplateWidgetPayload
}

struct TemplateProvider: TimelineProvider {
    func placeholder(in context: Context) -> TemplateEntry {
        TemplateEntry(date: .now, payload: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (TemplateEntry) -> Void) {
        completion(TemplateEntry(date: .now, payload: TemplateWidgetStore().readPayload()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TemplateEntry>) -> Void) {
        let entry = TemplateEntry(date: .now, payload: TemplateWidgetStore().readPayload())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct TemplateWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TemplateEntry

    private var favoriteTemplate: TemplateWidgetSnapshot? {
        entry.payload.favoriteTemplate
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumView
            case .accessoryCircular:
                circularView
            case .accessoryRectangular:
                rectangularView
            case .accessoryInline:
                inlineView
            default:
                smallView
            }
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if let template = favoriteTemplate {
                Text(template.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(template.summaryLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button(intent: StartFavoriteTemplateIntent(templateID: template.id)) {
                    Label("Start", systemImage: "play.fill")
                        .font(.callout.bold())
                }
                .buttonStyle(.borderedProminent)
            } else {
                emptyStateButton
            }
        }
        .foregroundStyle(.white)
    }

    private var mediumView: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                header

                if let template = favoriteTemplate {
                    Text(template.title)
                        .font(.title3.bold())
                        .lineLimit(2)

                    Text(template.detailLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("Pick a favorite")
                        .font(.title3.bold())
                    Text("Choose a template in Turn Timer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 10) {
                if let template = favoriteTemplate {
                    Text(template.totalDurationLabel)
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.secondary)

                    Button(intent: StartFavoriteTemplateIntent(templateID: template.id)) {
                        Label("Start", systemImage: "play.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    emptyStateButton
                }
            }
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var circularView: some View {
        if let template = favoriteTemplate {
            VStack(spacing: 3) {
                Image(systemName: "play.fill")
                    .font(.caption.bold())
                Text(template.totalDurationShortLabel)
                    .font(.caption2.monospacedDigit())
                    .minimumScaleFactor(0.7)
            }
        } else {
            Image(systemName: "star")
        }
    }

    @ViewBuilder
    private var rectangularView: some View {
        if let template = favoriteTemplate {
            Button(intent: StartFavoriteTemplateIntent(templateID: template.id)) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    VStack(alignment: .leading, spacing: 1) {
                        Text(template.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(template.totalDurationLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            Button(intent: OpenTemplatesIntent()) {
                Label("Pick favorite", systemImage: "star")
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var inlineView: some View {
        if let template = favoriteTemplate {
            Text("Turn Timer: \(template.title)")
        } else {
            Text("Turn Timer: Pick a favorite")
        }
    }

    private var header: some View {
        Label("Turn Timer", systemImage: "timer")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
    }

    private var emptyStateButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pick a favorite")
                .font(.headline)
                .lineLimit(2)
            Button(intent: OpenTemplatesIntent()) {
                Label("Open", systemImage: "star")
                    .font(.callout.bold())
            }
            .buttonStyle(.bordered)
        }
    }
}

private extension TemplateWidgetPayload {
    static let preview = TemplateWidgetPayload(
        favoriteTemplateID: "preview-template",
        templates: [
            TemplateWidgetSnapshot(
                id: "preview-template",
                title: "Game Night",
                subtitle: "4 rounds • once",
                roundCount: 4,
                repeatCount: 1,
                firstRoundName: "Alice",
                firstRoundDurationSeconds: 60,
                totalDurationSeconds: 300,
                modifiedAt: .now
            ),
        ],
        generatedAt: .now
    )
}

private extension TemplateWidgetSnapshot {
    var summaryLabel: String {
        "\(roundCount) rounds • \(totalDurationLabel)"
    }

    var detailLabel: String {
        "First: \(firstRoundName) • \(summaryLabel)"
    }

    var totalDurationLabel: String {
        Self.formattedDuration(totalDurationSeconds)
    }

    var totalDurationShortLabel: String {
        Self.formattedDuration(totalDurationSeconds, short: true)
    }

    private static func formattedDuration(_ seconds: Int, short: Bool = false) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        if minutes >= 60 {
            let hours = minutes / 60
            let leftoverMinutes = minutes % 60
            return leftoverMinutes == 0 ? "\(hours)h" : "\(hours)h \(leftoverMinutes)m"
        }

        if minutes > 0 {
            if short || remainingSeconds == 0 {
                return "\(minutes)m"
            }
            return "\(minutes)m \(remainingSeconds)s"
        }

        return "\(seconds)s"
    }
}

#Preview(as: .systemSmall) {
    TurnTimerTemplateWidget()
} timeline: {
    TemplateEntry(date: .now, payload: .preview)
}

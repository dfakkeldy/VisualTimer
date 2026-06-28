import SwiftUI
import WidgetKit

struct TemplateStartWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TemplateStartEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                TemplateStartMediumWidgetView(snapshot: entry.snapshot)
            case .accessoryCircular:
                TemplateStartCircularWidgetView(snapshot: entry.snapshot)
            case .accessoryRectangular:
                TemplateStartRectangularWidgetView(snapshot: entry.snapshot)
            case .accessoryInline:
                TemplateStartInlineWidgetView(snapshot: entry.snapshot)
            default:
                TemplateStartSmallWidgetView(snapshot: entry.snapshot)
            }
        }
        .widgetURL(entry.snapshot.launchURL)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

private struct TemplateStartSmallWidgetView: View {
    let snapshot: WidgetTemplateSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "timer")
                .font(.title3)
                .foregroundStyle(.tint)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(snapshot.durationText)
                    .font(.title2.monospacedDigit())
                    .bold()
            }

            Text(metadata)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding()
    }

    private var metadata: String {
        "\(snapshot.roundCount) rounds"
    }
}

private struct TemplateStartMediumWidgetView: View {
    let snapshot: WidgetTemplateSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.18))

                Image(systemName: "play.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(snapshot.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(snapshot.durationText)
                        .font(.title3.monospacedDigit())
                        .bold()

                    Text("\(snapshot.roundCount) rounds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
    }
}

private struct TemplateStartCircularWidgetView: View {
    let snapshot: WidgetTemplateSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 2) {
                Image(systemName: "timer")
                    .font(.caption)

                Text(snapshot.durationText)
                    .font(.caption2.monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
    }
}

private struct TemplateStartRectangularWidgetView: View {
    let snapshot: WidgetTemplateSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(snapshot.title)
                .font(.headline)
                .lineLimit(1)

            Text(snapshot.durationText)
                .font(.body.monospacedDigit())
                .bold()
                .lineLimit(1)

            Text("\(snapshot.roundCount) rounds")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct TemplateStartInlineWidgetView: View {
    let snapshot: WidgetTemplateSnapshot

    var body: some View {
        Text(snapshot.title)
        + Text(" ")
        + Text(snapshot.durationText)
    }
}

import SwiftUI
import Charts

/// Neutral target/actual bars with an always-visible, VoiceOver-readable table.
struct StopwatchComparisonView: View {
    let rows: [StopwatchViewModel.ComparisonRow]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var hasTargets: Bool { rows.contains { $0.step.targetSeconds != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Stopwatch.spacing) {
            if !dynamicTypeSize.isAccessibilitySize {
                Chart(rows) { row in
                    if let target = row.step.targetSeconds {
                        BarMark(x: .value(Theme.Stopwatch.seconds, target),
                                y: .value(Theme.Stopwatch.chooseStep, row.label))
                            .foregroundStyle(by: .value(Theme.Stopwatch.review, Theme.Stopwatch.target))
                            .position(by: .value(Theme.Stopwatch.review, Theme.Stopwatch.target))
                    }
                    BarMark(x: .value(Theme.Stopwatch.seconds, row.measurement.seconds),
                            y: .value(Theme.Stopwatch.chooseStep, row.label))
                        .foregroundStyle(by: .value(Theme.Stopwatch.review, Theme.Stopwatch.actual))
                        .position(by: .value(Theme.Stopwatch.review, Theme.Stopwatch.actual))
                }
                .chartForegroundStyleScale(domain: hasTargets ? [Theme.Stopwatch.target, Theme.Stopwatch.actual] : [Theme.Stopwatch.actual],
                                           range: hasTargets ? [Theme.Stopwatch.targetColor, Theme.Stopwatch.actualColor] : [Theme.Stopwatch.actualColor])
                .chartYScale(domain: rows.map(\.label))
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let seconds = value.as(Double.self) { Text(StopwatchText.duration(seconds)) }
                        }
                    }
                }
                .frame(height: max(Theme.Stopwatch.chartMinimumHeight, CGFloat(rows.count) * Theme.Stopwatch.chartRowHeight))
                .accessibilityElement(children: .ignore)
                .accessibilityHidden(true)
            }

            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: Theme.Stopwatch.smallSpacing) {
                    Text(row.label).font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(row.summary)
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ColorValue.textSecondary)
                    if let hint = row.appliedDurationHint {
                        Text(hint).font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Text(Theme.Stopwatch.neutralHint)
                .fixedSize(horizontal: false, vertical: true)
                .font(.caption)
                .foregroundStyle(Theme.ColorValue.textSecondary)
        }
    }
}

/// Dated measurements for one stable step identity, with original targets and
/// text alternatives. Shapes and a dashed stroke carry meaning without color.
struct StopwatchTrendView: View {
    let points: [StopwatchViewModel.TrendPoint]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Stopwatch.spacing) {
            if points.isEmpty {
                Text(Theme.Stopwatch.trendEmpty)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            } else {
                if !dynamicTypeSize.isAccessibilitySize {
                    Chart(points) { point in
                        LineMark(x: .value(Theme.Stopwatch.history, point.date),
                                 y: .value(Theme.Stopwatch.seconds, point.seconds),
                                 series: .value(Theme.Stopwatch.review, Theme.Stopwatch.actual))
                            .foregroundStyle(Theme.Stopwatch.actualColor)
                        PointMark(x: .value(Theme.Stopwatch.history, point.date),
                                  y: .value(Theme.Stopwatch.seconds, point.seconds))
                            .foregroundStyle(Theme.Stopwatch.actualColor)
                            .symbol(.circle)
                        if let target = point.step.targetSeconds {
                            LineMark(x: .value(Theme.Stopwatch.history, point.date),
                                     y: .value(Theme.Stopwatch.seconds, target),
                                     series: .value(Theme.Stopwatch.review, Theme.Stopwatch.target))
                                .interpolationMethod(.stepEnd)
                                .foregroundStyle(Theme.Stopwatch.targetColor)
                                .lineStyle(StrokeStyle(lineWidth: Theme.Stopwatch.chartLineWidth,
                                                       dash: Theme.Stopwatch.targetDash))
                            PointMark(x: .value(Theme.Stopwatch.history, point.date),
                                      y: .value(Theme.Stopwatch.seconds, target))
                                .foregroundStyle(Theme.Stopwatch.targetColor)
                                .symbol(.square)
                        }
                    }
                    .chartYScale(domain: .automatic(includesZero: true))
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let seconds = value.as(Double.self) { Text(StopwatchText.duration(seconds)) }
                            }
                        }
                    }
                    .frame(height: Theme.Stopwatch.chartHeight)
                    .accessibilityElement(children: .ignore)
                    .accessibilityHidden(true)
                }

                Text(dynamicTypeSize.isAccessibilitySize ? Theme.Stopwatch.accessibilityTrendHint : Theme.Stopwatch.trendHint)
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.caption)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                if points.count == 1 {
                    Text(Theme.Stopwatch.onePointHint).font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(points) { point in
                    VStack(alignment: .leading, spacing: Theme.Stopwatch.smallSpacing) {
                        Text(point.date.formatted(date: .abbreviated, time: .standard)).font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(point.step.name).font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(StopwatchText.comparison(step: point.step, actual: point.seconds))
                            .fixedSize(horizontal: false, vertical: true)
                            .font(.caption)
                            .foregroundStyle(Theme.ColorValue.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

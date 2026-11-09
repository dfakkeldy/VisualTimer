import SwiftUI
import Charts

/// Neutral target/actual bars with an always-visible, VoiceOver-readable table.
struct StopwatchComparisonView: View {
    let rows: [StopwatchViewModel.ComparisonRow]

    private var hasTargets: Bool { rows.contains { $0.step.targetSeconds != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Stopwatch.spacing) {
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
            .accessibilityHidden(true)

            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: Theme.Stopwatch.smallSpacing) {
                    Text(row.label).font(.headline)
                    Text(row.summary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ColorValue.textSecondary)
                    if let hint = row.appliedDurationHint {
                        Text(hint).font(.caption)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Text(Theme.Stopwatch.neutralHint)
                .font(.caption)
                .foregroundStyle(Theme.ColorValue.textSecondary)
        }
    }
}

/// Dated measurements for one stable step identity, with original targets and
/// text alternatives. Shapes and a dashed stroke carry meaning without color.
struct StopwatchTrendView: View {
    let points: [StopwatchViewModel.TrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Stopwatch.spacing) {
            if points.isEmpty {
                Text(Theme.Stopwatch.trendEmpty)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
            } else {
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
                .accessibilityHidden(true)

                Text(Theme.Stopwatch.trendHint)
                    .font(.caption)
                    .foregroundStyle(Theme.ColorValue.textSecondary)
                if points.count == 1 {
                    Text(Theme.Stopwatch.onePointHint).font(.subheadline)
                }
                ForEach(points) { point in
                    VStack(alignment: .leading, spacing: Theme.Stopwatch.smallSpacing) {
                        Text(point.date.formatted(date: .abbreviated, time: .standard)).font(.subheadline.weight(.semibold))
                        Text(point.step.name).font(.subheadline)
                        Text(StopwatchText.comparison(step: point.step, actual: point.seconds))
                            .font(.caption)
                            .foregroundStyle(Theme.ColorValue.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

//
//  WidgetPieChart.swift
//  TelemetryDeckWidget
//

import Charts
import DataTransferObjects
import SwiftUI
import WidgetKit

struct WidgetPieChart: View {
    let query: CustomQuery
    let result: QueryResult

    @Environment(\.widgetFamily) var family

    var body: some View {
        if query.queryType == .topN, case let .topN(topNResult) = result {
            if query.granularity == .all {
                pieChart(topNResult)
            } else {
                stackedBarChart(topNResult)
            }
        }
    }

    private func pieChart(_ result: TopNQueryResult) -> some View {
        let entries = pieEntries(result)

        return Chart {
            ForEach(Array(entries.prefix(itemLimit).enumerated()), id: \.offset) { _, entry in
                SectorMark(
                    angle: .value("Value", entry.value),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.0
                )
                .cornerRadius(2)
                .foregroundStyle(by: .value("Category", entry.label))
            }
        }
        .chartForegroundStyleScale(range: Color.chartColors)
        .chartLegend(family == .systemSmall || family == .systemMedium ? .hidden : .automatic)
    }

    private func stackedBarChart(_ result: TopNQueryResult) -> some View {
        let dimensionName = query.dimension?.name ?? "No value"
        let items = stackedItems(from: result)

        return Chart {
            ForEach(items, id: \.id) { item in
                BarMark(
                    x: .value("Date", item.timestamp, unit: query.granularityAsCalendarComponent),
                    y: .value("Value", item.value),
                    stacking: .normalized
                )
                .foregroundStyle(by: .value(dimensionName, item.label))
                .cornerRadius(2)
            }
        }
        .chartForegroundStyleScale(range: Color.chartColors)
        .chartLegend(.hidden)
        .chartXAxis(family == .systemSmall ? .hidden : .automatic)
        .chartYAxis(family == .systemSmall ? .hidden : .automatic)
        .widgetChartPadding(family: family)
    }

    // MARK: - Helpers

    private struct ChartItem: Identifiable {
        let id: String
        let timestamp: Date
        let label: String
        let value: Double
    }

    private func pieEntries(_ result: TopNQueryResult) -> [(label: String, value: Double)] {
        let dimensionName = query.dimension?.name ?? "No value"
        guard let metricName = query.metric?.name else { return [] }

        var entries: [(label: String, value: Double)] = []
        for row in result.rows {
            for item in row.result {
                guard let value = item.metrics[metricName],
                      let label = item.dimensions[dimensionName] else { continue }
                entries.append((label, value))
            }
        }
        return entries
    }

    private func stackedItems(from result: TopNQueryResult) -> [ChartItem] {
        let dimensionName = query.dimension?.name ?? "No value"
        guard let metricName = query.metric?.name else { return [] }

        var items: [ChartItem] = []
        for row in result.rows {
            for item in row.result.prefix(itemLimit) {
                guard let value = item.metrics[metricName],
                      let label = item.dimensions[dimensionName] else { continue }
                items.append(ChartItem(
                    id: "\(row.timestamp.timeIntervalSince1970)-\(label)",
                    timestamp: row.timestamp,
                    label: label,
                    value: value
                ))
            }
        }
        return items
    }

    private var itemLimit: Int {
        switch family {
        case .systemSmall: 5
        case .systemMedium: 8
        case .systemLarge: 15
        default: 15
        }
    }
}

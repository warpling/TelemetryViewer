//
//  WidgetBarChart.swift
//  TelemetryDeckWidget
//

import Charts
import DataTransferObjects
import SwiftUI
import WidgetKit

struct WidgetBarChart: View {
    let query: CustomQuery
    let result: QueryResult

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch query.queryType {
        case .timeseries:
            if case let .timeSeries(tsResult) = result {
                timeSeriesChart(tsResult)
            }
        case .topN:
            if case let .topN(topNResult) = result {
                topNChart(topNResult)
            }
        default:
            EmptyView()
        }
    }

    private func timeSeriesChart(_ result: TimeSeriesQueryResult) -> some View {
        let key = query.aggregations?.first?.name ?? "count"
        let rows = limitedRows(result.rows)

        return Chart {
            ForEach(rows, id: \.timestamp) { row in
                BarMark(
                    x: .value("Date", row.timestamp, unit: query.granularityAsCalendarComponent),
                    y: .value("Count", row.result[key]?.value ?? 0)
                )
                .foregroundStyle(Color.telemetryOrange)
                .cornerRadius(2)
            }
        }
        .chartXAxis(family == .systemSmall ? .hidden : .automatic)
        .chartYAxis(family == .systemSmall ? .hidden : .automatic)
        .widgetChartPadding(family: family)
    }

    private func topNChart(_ result: TopNQueryResult) -> some View {
        let dimensionName = query.dimension?.name ?? "No value"
        let items = topNItems(from: result)

        return Chart {
            ForEach(items, id: \.id) { item in
                BarMark(
                    x: .value("Date", item.timestamp, unit: query.granularityAsCalendarComponent),
                    y: .value("Value", item.value)
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

    private func topNItems(from result: TopNQueryResult) -> [ChartItem] {
        let dimensionName = query.dimension?.name ?? "No value"
        guard let metricName = query.metric?.name else { return [] }

        var items: [ChartItem] = []
        for row in result.rows {
            for item in limitedItems(row.result) {
                guard let value = item.metrics[metricName] else { continue }
                let label = item.dimensions[dimensionName] ?? "Unknown"
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

    private func limitedRows(_ rows: [TimeSeriesQueryResultRow]) -> [TimeSeriesQueryResultRow] {
        let limit = dataLimit
        if rows.count > limit {
            return Array(rows.suffix(limit))
        }
        return rows
    }

    private func limitedItems(_ items: [AdaptableQueryResultItem]) -> [AdaptableQueryResultItem] {
        Array(items.prefix(itemLimit))
    }

    private var dataLimit: Int {
        switch family {
        case .systemSmall: 7
        case .systemMedium: 14
        case .systemLarge: 30
        default: 30
        }
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

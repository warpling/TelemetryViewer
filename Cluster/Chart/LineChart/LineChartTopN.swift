//
//  LineChartTopN.swift
//  Telemetry Viewer (iOS)
//

import SwiftUI
import Charts
import DataTransferObjects
#if canImport(UIKit)
import UIKit
#endif

@available(macOS 13.0, iOS 16.0, *)
struct LineChartTopN: View {
    let topNQueryResult: TopNQueryResult
    let query: CustomQuery

    @State private var legendExpanded = false
    @State private var selectedDate: Date?
    @State private var lastSnappedDate: Date?

    private var legendNames: [String] {
        var seen = Set<String>()
        var names: [String] = []
        for row in topNQueryResult.rows {
            for rowResult in row.result {
                if let name = getMetricName(rowResult: rowResult), seen.insert(name).inserted {
                    names.append(name)
                }
            }
        }
        return names
    }

    var body: some View {
        VStack(spacing: 4) {
            if #available(macOS 14.0, iOS 17.0, *) {
                chart
                    .chartXSelection(value: $selectedDate)
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            if let selectedDate,
                               let snappedRow = closestRow(to: selectedDate),
                               let snappedX = proxy.position(forX: snappedRow.timestamp) {
                                Rectangle()
                                    .fill(Color.primary.opacity(0.15))
                                    .frame(width: 1)
                                    .frame(maxHeight: .infinity)
                                    .position(x: snappedX, y: geometry.size.height / 2)

                                let entries = tooltipEntries(for: selectedDate)
                                let tooltipWidth: CGFloat = 160
                                let gap: CGFloat = 16
                                let leftX = snappedX - tooltipWidth / 2 - gap
                                let tooltipX = leftX - tooltipWidth / 2 >= 0
                                    ? leftX
                                    : snappedX + tooltipWidth / 2 + gap
                                ChartTooltip(
                                    entries: entries,
                                    dateLabel: ChartTooltip.formatDate(snappedRow.timestamp)
                                )
                                .position(x: tooltipX, y: 50)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .onChange(of: selectedDate) { _, newDate in
                        guard let newDate, let closest = closestRow(to: newDate) else { return }
                        if closest.timestamp != lastSnappedDate {
                            lastSnappedDate = closest.timestamp
                            #if os(iOS)
                            UISelectionFeedbackGenerator().selectionChanged()
                            #endif
                        }
                    }
            } else {
                chart
            }

            CollapsibleLegend(names: legendNames, expanded: $legendExpanded)
        }
    }

    private var chart: some View {
        Chart {
            ForEach(topNQueryResult.rows, id: \.self) { (row: TopNQueryResultRow) in
                ForEach(row.result, id: \.self) { (rowResult: AdaptableQueryResultItem) in
                    ForEach(query.aggregations ?? [], id: \.self) { (aggregator: Aggregator) in
                        if let metricValue = getMetricValue(rowResult: rowResult),
                           let metricName = getMetricName(rowResult: rowResult) {
                            getLineMark(
                                timeStamp: row.timestamp,
                                name: aggregator.name,
                                metricValue: metricValue,
                                metricName: metricName
                            )
                        }
                    }
                }
            }

            if let selectedDate, let row = closestRow(to: selectedDate) {
                ForEach(row.result, id: \.self) { (item: AdaptableQueryResultItem) in
                    if let value = getMetricValue(rowResult: item),
                       let metricName = getMetricName(rowResult: item) {
                        PointMark(
                            x: .value("Date", row.timestamp, unit: query.granularityAsCalendarComponent),
                            y: .value("value", value)
                        )
                        .foregroundStyle(by: .value(query.dimension?.name ?? "No value", metricName))
                        .symbolSize(36)
                    }
                }
            }
        }
        .chartForegroundStyleScale(range: Color.chartColors)
        .chartLegend(.hidden)
    }

    private func closestRow(to date: Date) -> TopNQueryResultRow? {
        topNQueryResult.rows.min(by: { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) })
    }

    @available(macOS 14.0, iOS 17.0, *)
    private func tooltipEntries(for date: Date) -> [ChartTooltip.Entry] {
        guard let row = closestRow(to: date) else { return [] }
        return row.result.compactMap { item in
            guard let value = getMetricValue(rowResult: item),
                  let label = getMetricName(rowResult: item) else { return nil }
            let colorIndex = legendNames.firstIndex(of: label) ?? 0
            let color = Color.chartColors[colorIndex % Color.chartColors.count]
            return ChartTooltip.Entry(color: color, label: label, value: value)
        }
    }

    func getLineMark(timeStamp: Date, name: String, metricValue: Double, metricName: String) -> some ChartContent {
        return LineMark(
            x: .value("Date", timeStamp, unit: query.granularityAsCalendarComponent),
            y: .value(name, metricValue)
        )
        .foregroundStyle(by: .value(query.dimension?.name ?? "No value", metricName))
        .interpolationMethod(.cardinal)
    }

    func getMetricName(rowResult: AdaptableQueryResultItem) -> String? {
        let dimensionName = query.dimension?.name ?? "No value"
        return rowResult.dimensions[dimensionName]
    }

    func getMetricValue(rowResult: AdaptableQueryResultItem) -> Double? {
        guard let metricName = query.metric?.name else {
            return nil
        }
        let value = rowResult.metrics[metricName]
        return value
    }
}

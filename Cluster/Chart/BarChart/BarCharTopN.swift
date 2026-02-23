//
//  BarCharTopN.swift
//  Telemetry Viewer (iOS)
//
//  Created by Lukas on 23.05.24.
//

import SwiftUI
import Charts
import DataTransferObjects
#if canImport(UIKit)
import UIKit
#endif

@available(macOS 13.0, iOS 16.0, *)
struct BarChartTopN: View {
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
                let name = getMetricName(rowResult: rowResult)
                if seen.insert(name).inserted {
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
                               let midDate = binMidpoint(for: snappedRow.timestamp, unit: query.granularityAsCalendarComponent),
                               let snappedX = proxy.position(forX: midDate) {
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
                        if let metricValue = getMetricValue(rowResult: rowResult){
                            getBarMark(
                                timeStamp: row.timestamp,
                                name: aggregator.name,
                                metricValue: metricValue,
                                metricName: getMetricName(rowResult: rowResult)
                            )
                            .opacity(barOpacity(for: row.timestamp))
                        }
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

    private func barOpacity(for timestamp: Date) -> Double {
        guard let selectedDate, let closest = closestRow(to: selectedDate) else { return 1.0 }
        return closest.timestamp == timestamp ? 1.0 : 0.3
    }

    private func binMidpoint(for date: Date, unit: Calendar.Component) -> Date? {
        Calendar.current.date(byAdding: unit, value: 1, to: date)
            .map { Date(timeIntervalSince1970: (date.timeIntervalSince1970 + $0.timeIntervalSince1970) / 2) }
    }

    @available(macOS 14.0, iOS 17.0, *)
    private func tooltipEntries(for date: Date) -> [ChartTooltip.Entry] {
        guard let row = closestRow(to: date) else { return [] }
        return row.result.compactMap { item in
            guard let value = getMetricValue(rowResult: item) else { return nil }
            let label = getMetricName(rowResult: item)
            let colorIndex = legendNames.firstIndex(of: label) ?? 0
            let color = Color.chartColors[colorIndex % Color.chartColors.count]
            return ChartTooltip.Entry(color: color, label: label, value: value)
        }
    }

    func getBarMark(timeStamp: Date, name: String, metricValue: Double, metricName: String) -> some ChartContent {
        return BarMark(
            x: .value("Date", timeStamp, unit: query.granularityAsCalendarComponent),
            y: .value(name, metricValue)
        )
        .foregroundStyle(by: .value(query.dimension?.name ?? "No value", metricName))
        .cornerRadius(2)
    }

    func getMetricName(rowResult: AdaptableQueryResultItem) -> String{
        let dimensionName = query.dimension?.name ?? "No value"
        let metricName = rowResult.dimensions[dimensionName] ?? "Not found"
        return metricName
    }

    func getMetricValue(rowResult: AdaptableQueryResultItem) -> Double? {
        guard let metricName = query.metric?.name else {
            return nil
        }
        let value = rowResult.metrics[metricName]
        return value
    }

}

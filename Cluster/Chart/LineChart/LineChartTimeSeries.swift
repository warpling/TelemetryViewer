//
//  LineChartTimeSeries.swift
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
struct LineChartTimeSeries: View {
    let result: TimeSeriesQueryResult
    let query: CustomQuery

    @State private var selectedDate: Date?
    @State private var lastSnappedDate: Date?
    @State private var legendExpanded = false

    private var aggregationKeys: [String] {
        var seen = Set<String>()
        var keys: [String] = []
        for row in result.rows {
            for key in row.result.keys.sorted() {
                if seen.insert(key).inserted {
                    keys.append(key)
                }
            }
        }
        if keys.isEmpty, let first = query.aggregations?.first?.name {
            return [first]
        }
        return keys.isEmpty ? ["count"] : keys
    }

    private var isSingleSeries: Bool {
        aggregationKeys.count <= 1
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

                                let entries = tooltipEntries(for: snappedRow)
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

            if !isSingleSeries {
                CollapsibleLegend(names: aggregationKeys, expanded: $legendExpanded)
            }
        }
    }

    private var chart: some View {
        chartContent
            .if(!isSingleSeries) { chart in
                chart
                    .chartForegroundStyleScale(range: Color.chartColors)
                    .chartLegend(.hidden)
            }
    }

    @ViewBuilder
    private var chartContent: some View {
        if isSingleSeries {
            singleSeriesChart
        } else {
            multiSeriesChart
        }
    }

    private var singleSeriesChart: some View {
        let key = aggregationKeys[0]
        return Chart {
            ForEach(result.rows, id: \.timestamp) { row in
                LineMark(
                    x: .value("Date", row.timestamp),
                    y: .value(key, row.result[key]?.value ?? 0)
                )
            }
            .interpolationMethod(.cardinal)

            ForEach(result.rows, id: \.timestamp) { row in
                AreaMark(
                    x: .value("Date", row.timestamp),
                    y: .value(key, row.result[key]?.value ?? 0)
                )
            }
            .interpolationMethod(.cardinal)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.telemetryOrange.opacity(0.25), Color.telemetryOrange.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            if let selectedDate, let row = closestRow(to: selectedDate) {
                PointMark(
                    x: .value("Date", row.timestamp),
                    y: .value(key, row.result[key]?.value ?? 0)
                )
                .symbolSize(36)
                .foregroundStyle(Color.telemetryOrange)
            }
        }
    }

    private var multiSeriesChart: some View {
        Chart {
            ForEach(aggregationKeys, id: \.self) { key in
                ForEach(result.rows, id: \.timestamp) { row in
                    LineMark(
                        x: .value("Date", row.timestamp),
                        y: .value(key, row.result[key]?.value ?? 0)
                    )
                    .foregroundStyle(by: .value("Series", key))
                }
                .interpolationMethod(.cardinal)
            }

            if let selectedDate, let row = closestRow(to: selectedDate) {
                ForEach(aggregationKeys, id: \.self) { key in
                    PointMark(
                        x: .value("Date", row.timestamp),
                        y: .value(key, row.result[key]?.value ?? 0)
                    )
                    .foregroundStyle(by: .value("Series", key))
                    .symbolSize(36)
                }
            }
        }
    }

    private func closestRow(to date: Date) -> TimeSeriesQueryResultRow? {
        result.rows.min(by: { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) })
    }

    @available(macOS 14.0, iOS 17.0, *)
    private func tooltipEntries(for row: TimeSeriesQueryResultRow) -> [ChartTooltip.Entry] {
        aggregationKeys.enumerated().compactMap { index, key in
            let value = row.result[key]?.value ?? 0
            if isSingleSeries {
                return ChartTooltip.Entry(color: .telemetryOrange, label: key, value: value)
            }
            let color = Color.chartColors[index % Color.chartColors.count]
            return ChartTooltip.Entry(color: color, label: key, value: value)
        }
    }
}

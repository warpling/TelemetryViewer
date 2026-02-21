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

    private var aggregationKey: String {
        query.aggregations?.first?.name ?? "count"
    }

    var body: some View {
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

                            let value = snappedRow.result[aggregationKey]?.value ?? 0
                            let tooltipX: CGFloat = snappedX > geometry.size.width / 2
                                ? 88
                                : geometry.size.width - 88
                            ChartTooltip(
                                entries: [.init(color: .telemetryOrange, label: aggregationKey, value: value)],
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
    }

    private var chart: some View {
        Chart {
            ForEach(result.rows, id: \.timestamp) { row in
                LineMark(
                    x: .value("Date", row.timestamp),
                    y: .value("Total Count", row.result[aggregationKey]?.value ?? 0)
                )
            }
            .interpolationMethod(.cardinal)

            ForEach(result.rows, id: \.timestamp) { row in
                AreaMark(x: .value("Date", row.timestamp),
                         y: .value("Total Count", row.result[aggregationKey]?.value ?? 0))
            }
            .interpolationMethod(.cardinal)
            .foregroundStyle(LinearGradient(colors: [Color.telemetryOrange.opacity(0.25), Color.telemetryOrange.opacity(0.0)], startPoint: .top, endPoint: .bottom))

            if let selectedDate, let row = closestRow(to: selectedDate) {
                PointMark(
                    x: .value("Date", row.timestamp),
                    y: .value("Total Count", row.result[aggregationKey]?.value ?? 0)
                )
                .symbolSize(36)
                .foregroundStyle(Color.telemetryOrange)
            }
        }
    }

    private func closestRow(to date: Date) -> TimeSeriesQueryResultRow? {
        result.rows.min(by: { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) })
    }
}

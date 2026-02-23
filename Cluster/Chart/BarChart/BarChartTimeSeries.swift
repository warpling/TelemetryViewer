//
//  BarChartTimeSeries.swift
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
struct BarChartTimeSeries: View {
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
                           let midDate = binMidpoint(for: snappedRow.timestamp, unit: granularity()),
                           let snappedX = proxy.position(forX: midDate) {
                            Rectangle()
                                .fill(Color.primary.opacity(0.15))
                                .frame(width: 1)
                                .frame(maxHeight: .infinity)
                                .position(x: snappedX, y: geometry.size.height / 2)

                            let value = snappedRow.result[aggregationKey]?.value ?? 0
                            let tooltipWidth: CGFloat = 160
                            let gap: CGFloat = 16
                            let leftX = snappedX - tooltipWidth / 2 - gap
                            let tooltipX = leftX - tooltipWidth / 2 >= 0
                                ? leftX
                                : snappedX + tooltipWidth / 2 + gap
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
                BarMark(
                    x: .value("Date", row.timestamp, unit: granularity()),
                    y: .value("Total Count", row.result[aggregationKey]?.value ?? 0)
                )
                .cornerRadius(2)
                .opacity(barOpacity(for: row.timestamp))
            }
        }
    }

    private func closestRow(to date: Date) -> TimeSeriesQueryResultRow? {
        result.rows.min(by: { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) })
    }

    private func barOpacity(for timestamp: Date) -> Double {
        guard let selectedDate, let closest = closestRow(to: selectedDate) else { return 1.0 }
        return closest.timestamp == timestamp ? 1.0 : 0.3
    }

    private func binMidpoint(for date: Date, unit: Calendar.Component) -> Date? {
        Calendar.current.date(byAdding: unit, value: 1, to: date)
            .map { Date(timeIntervalSince1970: (date.timeIntervalSince1970 + $0.timeIntervalSince1970) / 2) }
    }

    // swiftlint:disable cyclomatic_complexity
    func granularity() -> Calendar.Component{
        switch query.granularity {
        case .all:
                .month
        case .none:
                .month
        case .second:
                .hour
        case .minute:
                .hour
        case .fifteen_minute:
                .hour
        case .thirty_minute:
                .hour
        case .hour:
                .hour
        case .day:
                .day
        case .week:
                .weekOfYear
        case .month:
                .month
        case .quarter:
                .quarter
        case .year:
                .year
        }
    }
    // swiftlint:enable cyclomatic_complexity
}

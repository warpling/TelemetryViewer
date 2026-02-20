//
//  BarChartTimeSeries.swift
//  Telemetry Viewer (iOS)
//
//  Created by Lukas on 23.05.24.
//

import SwiftUI
import Charts
import DataTransferObjects

@available(macOS 13.0, iOS 16.0, *)
struct BarChartTimeSeries: View {
    let result: TimeSeriesQueryResult
    let query: CustomQuery

    private var aggregationKey: String {
        query.aggregations?.first?.name ?? "count"
    }

    var body: some View {
        Chart {
            ForEach(result.rows, id: \.timestamp) { row in
                BarMark(
                    x: .value("Date", row.timestamp, unit: granularity()),
                    y: .value("Total Count", row.result[aggregationKey]?.value ?? 0)
                )
                .cornerRadius(2)
            }
        }
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

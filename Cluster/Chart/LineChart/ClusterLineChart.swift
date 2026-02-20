//
//  ClusterLineChart.swift
//  Telemetry Viewer (iOS)
//
//  Created by Lukas on 23.05.24.
//

import SwiftUI
import DataTransferObjects

struct ClusterLineChart: View {
    let query: CustomQuery
    let result: QueryResult

    var body: some View {
        if #available(macOS 13.0, iOS 16.0, *) {
            switch query.queryType {
            case .timeseries:
                if case let .timeSeries(result) = result {
                    LineChartTimeSeries(result: result, query: query)
                } else {
                    DashboardLink()
                }
            case .topN:
                if case let .topN(result) = result {
                    LineChartTopN(topNQueryResult: result, query: query)
                } else {
                    DashboardLink()
                }
            default:
                DashboardLink()
            }
        } else {
            DashboardLink()
        }
    }
}

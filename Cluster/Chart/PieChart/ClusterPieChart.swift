//
//  ClusterPieChart.swift
//  Telemetry Viewer (iOS)
//
//  Created by Lukas on 28.05.24.
//

import SwiftUI
import DataTransferObjects

struct ClusterPieChart: View {
    let query: CustomQuery
    let result: QueryResult

    var body: some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            switch query.queryType {
            case .topN:
                if case let .topN(result) = result {
                    PieChartTopN(topNQueryResult: result, query: query)
                }
            default:
                Text("\(query.queryType.rawValue) bar charts are not supported.")
            }
        } else {
            Text("Charts require macOS 13.0 or later.")
        }
    }
}

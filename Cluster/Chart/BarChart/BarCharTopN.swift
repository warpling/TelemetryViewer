//
//  BarCharTopN.swift
//  Telemetry Viewer (iOS)
//
//  Created by Lukas on 23.05.24.
//

import SwiftUI
import Charts
import DataTransferObjects

@available(macOS 13.0, iOS 16.0, *)
struct BarChartTopN: View {
    let topNQueryResult: TopNQueryResult
    let query: CustomQuery

    var body: some View {

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
                        }
                    }

                }

            }
        }
        .chartForegroundStyleScale(range: Color.chartColors)

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

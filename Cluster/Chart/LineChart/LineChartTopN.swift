//
//  LineChartTopN.swift
//  Telemetry Viewer (iOS)
//

import SwiftUI
import Charts
import DataTransferObjects

@available(macOS 13.0, iOS 16.0, *)
struct LineChartTopN: View {
    let topNQueryResult: TopNQueryResult
    let query: CustomQuery

    @State private var legendExpanded = false

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
            Chart {
                ForEach(topNQueryResult.rows, id: \.self) { (row: TopNQueryResultRow) in
                    ForEach(row.result, id: \.self) { (rowResult: AdaptableQueryResultItem) in
                        ForEach(query.aggregations ?? [], id: \.self) { (aggregator: Aggregator) in
                            if let metricValue = getMetricValue(rowResult: rowResult) {
                                getLineMark(
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
            .chartLegend(.hidden)

            CollapsibleLegend(names: legendNames, expanded: $legendExpanded)
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

    func getMetricName(rowResult: AdaptableQueryResultItem) -> String {
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

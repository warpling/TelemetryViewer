//
//  MockData.swift
//  TelemetryDeckWidget
//
//  Created by Charlotte Bohm on 05.10.21.
//

// swiftlint:disable all

import DataTransferObjects
import Foundation

// MARK: - Mock time series data for widget previews

let mockTimeSeriesResult: TimeSeriesQueryResult = {
    let calendar = Calendar.current
    let endDate = Date()
    let rows: [TimeSeriesQueryResultRow] = (0..<30).reversed().map { daysAgo in
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: endDate)!
        let value = Double.random(in: 30...80)
        return TimeSeriesQueryResultRow(
            timestamp: date,
            result: ["count": DoubleWrapper(value)]
        )
    }
    return TimeSeriesQueryResult(rows: rows)
}()

let mockTopNResult: TopNQueryResult = {
    let calendar = Calendar.current
    let endDate = Date()
    let deviceNames = ["iPhone 15 Pro", "iPhone 14", "iPad Pro", "iPhone SE", "iPad Air"]
    let rows: [TopNQueryResultRow] = (0..<7).reversed().map { daysAgo in
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: endDate)!
        let items: [AdaptableQueryResultItem] = deviceNames.map { name in
            AdaptableQueryResultItem(
                metrics: ["count": Double.random(in: 10...100)],
                dimensions: ["device": name]
            )
        }
        return TopNQueryResultRow(timestamp: date, result: items)
    }
    return TopNQueryResult(rows: rows)
}()

let mockPieTopNResult: TopNQueryResult = {
    let deviceNames = ["iOS 18.0": 2774.0, "iOS 17.6": 1500.0, "iOS 17.5": 394.0, "iOS 16.0": 335.0, "macOS 15.0": 157.0]
    let items: [AdaptableQueryResultItem] = deviceNames.map { name, count in
        AdaptableQueryResultItem(
            metrics: ["count": count],
            dimensions: ["os": name]
        )
    }
    let row = TopNQueryResultRow(timestamp: Date(), result: items)
    return TopNQueryResult(rows: [row])
}()

let mockFunnelResult: GroupByQueryResult = {
    let row = GroupByQueryResultRow(
        timestamp: Date(),
        event: AdaptableQueryResultItem(
            metrics: [
                "0_App Launched": 5000,
                "1_Signed Up": 2500,
                "2_Subscribed": 800,
                "3_Upgraded": 200
            ],
            dimensions: [:]
        )
    )
    return GroupByQueryResult(rows: [row])
}()

let mockBarQuery = CustomQuery(
    queryType: .timeseries,
    granularity: .day,
    aggregations: [.count(CountAggregator(name: "count"))]
)

let mockTopNQuery = CustomQuery(
    queryType: .topN,
    granularity: .day,
    aggregations: [.count(CountAggregator(name: "count"))],
    metric: .numeric(NumericTopNMetricSpec(metric: "count")),
    dimension: .default(DefaultDimensionSpec(dimension: "device", outputName: "device"))
)

let mockPieQuery = CustomQuery(
    queryType: .topN,
    granularity: .all,
    aggregations: [.count(CountAggregator(name: "count"))],
    metric: .numeric(NumericTopNMetricSpec(metric: "count")),
    dimension: .default(DefaultDimensionSpec(dimension: "os", outputName: "os"))
)

let mockFunnelQuery = CustomQuery(
    queryType: .groupBy,
    granularity: .all,
    aggregations: [.count(CountAggregator(name: "count"))]
)

// swiftlint:enable all

//
//  WidgetClusterChart.swift
//  TelemetryDeckWidget
//

import SwiftUI
import DataTransferObjects
import WidgetKit

struct WidgetClusterChart: View {
    let query: CustomQuery
    let result: QueryResult
    let type: InsightDisplayMode

    var body: some View {
        switch type {
        case .barChart:
            WidgetBarChart(query: query, result: result)
        case .lineChart:
            WidgetLineChart(query: query, result: result)
        case .pieChart:
            WidgetPieChart(query: query, result: result)
        case .raw, .number:
            WidgetRawTable(query: query, result: result)
        case .funnelChart:
            WidgetFunnelChart(query: query, result: result)
        default:
            Text("View on dashboard")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Chart padding for axis labels

extension View {
    func widgetChartPadding(family: WidgetFamily) -> some View {
        self.padding(
            family == .systemSmall
                ? EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                : EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 8)
        )
    }
}

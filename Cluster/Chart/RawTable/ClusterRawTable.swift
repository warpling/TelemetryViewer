//
//  ClusterRawTable.swift
//  Telemetry Viewer
//

import SwiftUI
import DataTransferObjects

struct ClusterRawTable: View {
    let query: CustomQuery
    let result: QueryResult

    private var rows: [(label: String, value: Double)] {
        switch result {
        case .timeSeries(let tsResult):
            let key = query.aggregations?.first?.name ?? "count"
            return tsResult.rows.map { row in
                let label = Self.formatDate(row.timestamp, granularity: query.granularity)
                let value = row.result[key]?.value ?? 0
                return (label, value)
            }

        case .topN(let topNResult):
            let dimensionName = query.dimension?.name ?? "No value"
            let metricName = query.metric?.name ?? query.aggregations?.first?.name ?? "count"
            return topNResult.rows.flatMap { row in
                row.result.compactMap { item in
                    guard let label = item.dimensions[dimensionName] else { return nil }
                    let value = item.metrics[metricName] ?? 0
                    return (label, value)
                }
            }

        case .groupBy(let gbResult):
            let metricName = query.aggregations?.first?.name ?? "count"
            return gbResult.rows.map { row in
                let label = row.event.dimensions.values.joined(separator: ", ")
                    .ifEmpty(Self.formatDate(row.timestamp, granularity: query.granularity))
                let value = row.event.metrics[metricName] ?? 0
                return (label, value)
            }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: nil, alignment: .leading),
        GridItem(.flexible(), spacing: nil, alignment: .trailing)
    ]

    var body: some View {
        if rows.isEmpty {
            DashboardLink()
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        Text(row.label)
                            .font(.footnote)
                            .foregroundStyle(Color.Zinc400)
                            .lineLimit(1)

                        Text(Self.formatNumber(row.value))
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(Color.Zinc600)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private static func formatDate(_ date: Date, granularity: QueryGranularity?) -> String {
        let formatter = DateFormatter()
        switch granularity {
        case .hour:
            formatter.dateStyle = .short
            formatter.timeStyle = .short
        case .day:
            formatter.dateStyle = .medium
            formatter.timeZone = TimeZone(abbreviation: "UTC")
        case .week:
            formatter.dateStyle = .medium
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            return "Week of \(formatter.string(from: date))"
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
            formatter.timeZone = TimeZone(abbreviation: "UTC")
        default:
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        }
        return formatter.string(from: date)
    }

    private static func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1_000_000 {
            return String(format: "%.0f", value)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

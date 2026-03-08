//
//  WidgetRawTable.swift
//  TelemetryDeckWidget
//

import DataTransferObjects
import SwiftUI
import WidgetKit

struct WidgetRawTable: View {
    let query: CustomQuery
    let result: QueryResult

    @Environment(\.widgetFamily) var family

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
                let value = row.event.metrics[metricName] ?? 0
                return (label.isEmpty ? Self.formatDate(row.timestamp, granularity: query.granularity) : label, value)
            }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: nil, alignment: .leading),
        GridItem(.flexible(), spacing: nil, alignment: .trailing)
    ]

    var body: some View {
        let displayRows = Array(rows.prefix(rowLimit))
        if displayRows.isEmpty {
            Text("No data")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(displayRows.enumerated()), id: \.offset) { _, row in
                    Text(row.label)
                        .font(.caption2)
                        .foregroundStyle(Color.Zinc400)
                        .lineLimit(1)

                    Text(Self.formatNumber(row.value))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color.Zinc600)
                }
            }
            .padding(.horizontal)
        }
    }

    private var rowLimit: Int {
        switch family {
        case .systemSmall: 5
        case .systemMedium: 10
        case .systemLarge: 20
        default: 20
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

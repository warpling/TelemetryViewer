//
//  WidgetFunnelChart.swift
//  TelemetryDeckWidget
//

import DataTransferObjects
import SwiftUI
import WidgetKit

struct WidgetFunnelChart: View {
    let query: CustomQuery
    let result: QueryResult

    @Environment(\.widgetFamily) var family

    private var steps: [(name: String, value: Double)] {
        guard case .groupBy(let gbResult) = result,
              let firstRow = gbResult.rows.first else {
            return []
        }

        return firstRow.event.metrics
            .filter { $0.key.first?.isNumber == true }
            .sorted { lhs, rhs in
                let lhsPrefix = lhs.key.prefix(while: { $0.isNumber })
                let rhsPrefix = rhs.key.prefix(while: { $0.isNumber })
                return (Int(lhsPrefix) ?? 0) < (Int(rhsPrefix) ?? 0)
            }
            .map { key, value in
                let name: String
                if let underscoreIndex = key.firstIndex(of: "_") {
                    name = String(key[key.index(after: underscoreIndex)...])
                } else {
                    name = key
                }
                return (name, value)
            }
    }

    var body: some View {
        if steps.isEmpty {
            Text("No data")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            GeometryReader { geometry in
                let maxValue = steps.first?.value ?? 1
                let barHeight = max(12, (geometry.size.height - CGFloat(steps.count - 1) * 2) / CGFloat(steps.count))

                VStack(spacing: 2) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        let fraction = maxValue > 0 ? step.value / maxValue : 0
                        let barWidth = max(geometry.size.width * 0.1, geometry.size.width * fraction)

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.chartColors[index % Color.chartColors.count])
                                .frame(width: barWidth, height: barHeight)

                            HStack(spacing: 4) {
                                if family != .systemSmall {
                                    Text(step.name)
                                        .lineLimit(1)
                                }
                                Text(Self.formatNumber(step.value))
                                if index > 0 && family != .systemSmall {
                                    Text(Self.conversionLabel(from: steps[index - 1].value, to: step.value))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 0)
                            .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 0)
                            .padding(.horizontal, 6)
                            .frame(height: barHeight)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private static func conversionLabel(from previous: Double, to current: Double) -> String {
        guard previous > 0 else { return "" }
        let pct = (current / previous) * 100
        return String(format: "(%.0f%%)", pct)
    }

    private static func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1_000_000 {
            return String(format: "%.0f", value)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

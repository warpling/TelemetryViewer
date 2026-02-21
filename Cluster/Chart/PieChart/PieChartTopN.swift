//
//  PieChartGroupBy.swift
//  Telemetry Viewer (iOS)
//
//  Created by Lukas on 28.05.24.
//

import SwiftUI
import Charts
import DataTransferObjects
#if canImport(UIKit)
import UIKit
#endif

@available(macOS 14.0, iOS 17.0, *)
struct PieChartTopN: View {
    let topNQueryResult: TopNQueryResult
    let query: CustomQuery

    @State private var legendExpanded = false
    @State private var selectedAngle: Double?
    @State private var selectedDate: Date?
    @State private var lastSnappedDate: Date?
    @State private var lastSnappedSector: String?

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
            if query.granularity == .all {
                pieChart
            } else {
                barChart
            }

            CollapsibleLegend(names: legendNames, expanded: $legendExpanded)
        }

    }

    private var selectedSectorName: String? {
        guard let angle = selectedAngle else { return nil }
        var cumulative = 0.0
        for entry in pieEntries() {
            cumulative += entry.value
            if angle <= cumulative {
                return entry.label
            }
        }
        return nil
    }

    private func sectorOpacity(for metricName: String) -> Double {
        selectedSectorName == nil || selectedSectorName == metricName ? 1.0 : 0.3
    }

    private var pieChart: some View {
        Chart {
            ForEach(topNQueryResult.rows, id: \.self) { (row: TopNQueryResultRow) in
                ForEach(row.result, id: \.self) { (rowResult: AdaptableQueryResultItem) in
                    ForEach(query.aggregations ?? [], id: \.self) { (aggregator: Aggregator) in
                        if let metricValue = getMetricValue(rowResult: rowResult){
                            getSectorMark(
                                name: aggregator.name,
                                metricValue: metricValue,
                                metricName: getMetricName(rowResult: rowResult)
                            )
                            .opacity(sectorOpacity(for: getMetricName(rowResult: rowResult)))
                        }
                    }
                }
            }
        }
        .chartForegroundStyleScale(range: Color.chartColors)
        .chartLegend(.hidden)
        .chartAngleSelection(value: $selectedAngle)
        .onChange(of: selectedAngle) { _, _ in
            if selectedSectorName != lastSnappedSector {
                lastSnappedSector = selectedSectorName
                #if os(iOS)
                UISelectionFeedbackGenerator().selectionChanged()
                #endif
            }
        }
        .chartOverlay { _ in
            GeometryReader { geometry in
                if let selected = selectedSector() {
                    VStack(spacing: 2) {
                        Circle()
                            .fill(selected.color)
                            .frame(width: 8, height: 8)
                        Text(selected.label)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(formatValue(selected.value))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }
            .allowsHitTesting(false)
        }
    }

    private var barChart: some View {
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
                            .opacity(barOpacity(for: row.timestamp))
                        }
                    }
                }
            }
        }
        .chartForegroundStyleScale(range: Color.chartColors)
        .chartLegend(.hidden)
        .chartXSelection(value: $selectedDate)
        .onChange(of: selectedDate) { _, newDate in
            guard let newDate, let closest = closestRow(to: newDate) else { return }
            if closest.timestamp != lastSnappedDate {
                lastSnappedDate = closest.timestamp
                #if os(iOS)
                UISelectionFeedbackGenerator().selectionChanged()
                #endif
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let selectedDate,
                   let snappedRow = closestRow(to: selectedDate),
                   let midDate = binMidpoint(for: snappedRow.timestamp, unit: query.granularityAsCalendarComponent),
                   let snappedX = proxy.position(forX: midDate) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.15))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .position(x: snappedX, y: geometry.size.height / 2)

                    let entries = tooltipEntries(for: selectedDate)
                    let tooltipX: CGFloat = snappedX > geometry.size.width / 2
                        ? 88
                        : geometry.size.width - 88
                    ChartTooltip(
                        entries: entries,
                        dateLabel: ChartTooltip.formatDate(snappedRow.timestamp)
                    )
                    .position(x: tooltipX, y: 50)
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func selectedSector() -> (label: String, value: Double, color: Color)? {
        guard let angle = selectedAngle else { return nil }
        var cumulative = 0.0
        let entries = pieEntries()
        for (index, entry) in entries.enumerated() {
            cumulative += entry.value
            if angle <= cumulative {
                let color = Color.chartColors[index % Color.chartColors.count]
                return (entry.label, entry.value, color)
            }
        }
        return nil
    }

    private func pieEntries() -> [(label: String, value: Double)] {
        var entries: [(label: String, value: Double)] = []
        for row in topNQueryResult.rows {
            for item in row.result {
                guard let value = getMetricValue(rowResult: item) else { continue }
                let label = getMetricName(rowResult: item)
                entries.append((label, value))
            }
        }
        return entries
    }

    private func closestRow(to date: Date) -> TopNQueryResultRow? {
        topNQueryResult.rows.min(by: { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) })
    }

    private func barOpacity(for timestamp: Date) -> Double {
        guard let selectedDate, let closest = closestRow(to: selectedDate) else { return 1.0 }
        return closest.timestamp == timestamp ? 1.0 : 0.3
    }

    private func binMidpoint(for date: Date, unit: Calendar.Component) -> Date? {
        Calendar.current.date(byAdding: unit, value: 1, to: date)
            .map { Date(timeIntervalSince1970: (date.timeIntervalSince1970 + $0.timeIntervalSince1970) / 2) }
    }

    private func tooltipEntries(for date: Date) -> [ChartTooltip.Entry] {
        guard let row = closestRow(to: date) else { return [] }
        return row.result.compactMap { item in
            guard let value = getMetricValue(rowResult: item) else { return nil }
            let label = getMetricName(rowResult: item)
            let colorIndex = legendNames.firstIndex(of: label) ?? 0
            let color = Color.chartColors[colorIndex % Color.chartColors.count]
            return ChartTooltip.Entry(color: color, label: label, value: value)
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 10_000 { return String(format: "%.1fK", value / 1_000) }
        if value == value.rounded() { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }

    func getSectorMark(name: String, metricValue: Double, metricName: String) -> some ChartContent {
        return SectorMark(
            angle: .value(name, metricValue),
            innerRadius: .ratio(0.5),
            angularInset: 1.0
        )
        .cornerRadius(2)
        .foregroundStyle(by: .value(query.dimension?.name ?? "No value", metricName))
    }

    func getBarMark(timeStamp: Date, name: String, metricValue: Double, metricName: String) -> some ChartContent {
        return BarMark(
            x: .value("Date", timeStamp, unit: query.granularityAsCalendarComponent),
            y: .value(name, metricValue),
            stacking: .normalized
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

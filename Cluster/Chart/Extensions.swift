//
//  Extensions.swift
//  Telemetry Viewer (iOS)
//
//  Created by Lukas on 28.05.24.
//

import Foundation
import SwiftUI
import DataTransferObjects

struct DashboardLink: View {
    var body: some View {
        Link(destination: URL(string: "https://dashboard.telemetrydeck.com")!) {
            HStack(spacing: 4) {
                Text("View on dashboard.telemetrydeck.com")
                Image(systemName: "arrow.up.right")
            }
            .font(.footnote)
            .foregroundStyle(Color.Zinc400)
        }
    }
}

@available(macOS 13.0, iOS 16.0, *)
struct CollapsibleLegend: View {
    let names: [String]
    @Binding var expanded: Bool

    private var maxCollapsed: Int { 3 }

    private var shouldCollapse: Bool {
        names.count > maxCollapsed + 1
    }

    private var visibleNames: [String] {
        if shouldCollapse && !expanded {
            return Array(names.prefix(maxCollapsed))
        }
        return names
    }

    var body: some View {
        if !names.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                FlowLayout(spacing: 6) {
                    ForEach(Array(visibleNames.enumerated()), id: \.offset) { index, name in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.chartColors[index % Color.chartColors.count])
                                .frame(width: 6, height: 6)
                            Text(name)
                                .lineLimit(1)
                        }
                    }

                    if shouldCollapse {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expanded.toggle()
                            }
                        } label: {
                            Text(expanded ? "Less" : "+\(names.count - maxCollapsed) more")
                                .foregroundStyle(Color.Zinc400)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(Color.Zinc600)
            .padding(.horizontal, 8)
        }
    }
}

@available(macOS 13.0, iOS 16.0, *)
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

extension CustomQuery {
    var granularityAsCalendarComponent: Calendar.Component{
        switch self.granularity {
        case .all:
                .month
        case .none:
                .month
        case .second:
                .hour
        case .minute:
                .hour
        case .fifteen_minute:
                .hour
        case .thirty_minute:
                .hour
        case .hour:
                .hour
        case .day:
                .day
        case .week:
                .weekOfYear
        case .month:
                .month
        case .quarter:
                .quarter
        case .year:
                .year
        }
    }
}

extension Aggregator {
    var name: String {
        switch self {
        case .count(let a):
            a.name
        case .cardinality(let a):
            a.name
        case .longSum(let a):
            a.name
        case .doubleSum(let a):
            a.name
        case .floatSum(let a):
            a.name
        case .doubleMin(let a):
            a.name
        case .doubleMax(let a):
            a.name
        case .floatMin(let a):
            a.name
        case .floatMax(let a):
            a.name
        case .longMin(let a):
            a.name
        case .longMax(let a):
            a.name
        case .doubleMean(let a):
            a.name
        case .doubleFirst(let a):
            a.name
        case .doubleLast(let a):
            a.name
        case .floatFirst(let a):
            a.name
        case .floatLast(let a):
            a.name
        case .longFirst(let a):
            a.name
        case .longLast(let a):
            a.name
        case .stringFirst(let a):
            a.name
        case .stringLast(let a):
            a.name
        case .doubleAny(let a):
            a.name
        case .floatAny(let a):
            a.name
        case .longAny(let a):
            a.name
        case .stringAny(let a):
            a.name
        case .thetaSketch(let a):
            a.name
        case .filtered(let a):
            a.aggregator.name
        }
    }
}

extension DimensionSpec {
    var name: String? {
        switch self {
        case .default(let defaultDimensionSpec):
            defaultDimensionSpec.outputName
        case .extraction(let extractionDimensionSpec):
            extractionDimensionSpec.outputName
        }
    }
}

extension TopNMetricSpec {
    var name: String? {
        switch self {
        case .numeric(let numericTopNMetricSpec):
            return numericTopNMetricSpec.metric
        case .inverted(let invertedTopNMetricSpec):
            return invertedTopNMetricSpec.metric.name
        default:
            return nil
        }
    }
}

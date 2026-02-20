//
//  InsightsGrid.swift
//  Telemetry Viewer
//
//  Created by Daniel Jilg on 24.09.21.
//

import DataTransferObjects
import SwiftUI

struct UnsupportedInsightCard: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(Color.Zinc600)

            DashboardLink()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background)
        .shadow(color: .gray.opacity(0.15), radius: 5, x: 0, y: 2)
        .border(Color.Zinc200, width: 1.0)
        .padding(.vertical, 5)
    }
}

struct InsightsGrid: View {
    @EnvironmentObject var insightService: InsightService
    @Binding var selectedInsightID: DTOv2.Insight.ID?
    @Binding var sidebarVisible: Bool

    let insightGroup: InsightGroupInfo
    let isSelectable: Bool

    private static let unsupportedDisplayModes: Set<InsightDisplayMode> = [
        .experimentChart, .matrix
    ]

    var body: some View {
        VStack {
            ForEach(insightGroup.insights ?? [], id: \.id) { insight in
                if let query = insight.query,
                   !Self.unsupportedDisplayModes.contains(insight.displayMode) {
                    ClusterInstrument(query: query, title: insight.title, type: insight.displayMode)
                } else {
                    UnsupportedInsightCard(title: insight.title)
                }
            }
        }
    }
}

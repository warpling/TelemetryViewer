//
//  InsightsGrid.swift
//  Telemetry Viewer
//
//  Created by Daniel Jilg on 24.09.21.
//

import DataTransferObjects
import SwiftUI

struct InsightsGrid: View {
    @EnvironmentObject var insightService: InsightService
    @Binding var selectedInsightID: InsightInfo.ID?
    @Binding var sidebarVisible: Bool

    let insightGroup: InsightGroupInfo
    let isSelectable: Bool

    private static let unsupportedDisplayModes: Set<InsightDisplayMode> = [
        .experimentChart, .matrix
    ]

    // MARK: - WORKAROUND: Missing dataSource on pre-namespacing insights
    //
    // TelemetryDeck migrated to namespaced data sources (e.g. "com.growpixel" instead of
    // the legacy "telemetry-signals"). Insight queries created before this migration are
    // missing the `dataSource` field. When the API receives a query without `dataSource`,
    // it falls back to a data source with limited historical data, causing charts to show
    // only ~3 weeks of data regardless of the selected date range.
    //
    // This workaround extracts `dataSource` from any sibling query in the same insight
    // group that has one (post-migration insights) and injects it into queries that lack it.
    //
    // TODO: Remove this workaround once the TelemetryDeck API populates `dataSource` on
    // all insight queries server-side. To verify: check if queries in the `📤` debug log
    // all have `dataSource` set without this patch. See also: macOS/InsightsGrid.swift.

    /// Finds the namespaced `dataSource` from any sibling insight query in this group.
    private var groupDataSource: DataSource? {
        insightGroup.insights?
            .lazy
            .compactMap { $0.query?.dataSource }
            .first
    }

    var body: some View {
        LazyVStack {
            ForEach(insightGroup.insights ?? [], id: \.id) { insight in
                if let query = insight.query,
                   !Self.unsupportedDisplayModes.contains(insight.displayMode) {
                    ClusterInstrument(
                        query: Self.withDataSource(query, fallback: groupDataSource),
                        title: insight.title,
                        type: insight.displayMode
                    )
                } else {
                    UnsupportedInsightCard(title: insight.title)
                }
            }
        }
    }

    /// Patches queries missing `dataSource` with the value from a sibling query.
    /// See WORKAROUND comment above.
    private static func withDataSource(_ query: CustomQuery, fallback: DataSource?) -> CustomQuery {
        guard query.dataSource == nil, let dataSource = fallback else { return query }
        var patched = query
        patched.dataSource = dataSource
        return patched
    }
}

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

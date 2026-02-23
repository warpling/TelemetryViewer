//
//  TelemetryDeckWidgetEntryViews.swift
//  TelemetryDeckWidgetEntryViews
//
//  Created by Charlotte Bohm on 17.10.21.
//

import DataTransferObjects
import SwiftUI
import WidgetKit

struct TelemetryDeckWidgetEntryView: View {
    let entry: TelemetryWidgetEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch entry.state {
            case .placeholder:
                placeholderView
                    .redacted(reason: .placeholder)

            case .chooseInsight:
                chooseInsightView

            case .normal(let query, let result):
                normalView(query: query, result: result)

            case .error(let message):
                errorView(message: message)
            }
        }
        .widgetURL(entry.deepLinkURL)
    }

    private func normalView(query: CustomQuery, result: QueryResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            headerRow
                .padding(.top, family == .systemSmall ? 8 : 10)
                .padding(.horizontal, family == .systemSmall ? 10 : 16)

            if let chartType = entry.chartType {
                WidgetClusterChart(query: query, result: result, type: chartType)
                    .padding(.horizontal, family == .systemSmall ? 4 : 8)
                    .padding(.bottom, family == .systemSmall ? 4 : 8)
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 4) {
            titleLabel

            Spacer(minLength: 2)

            Button(intent: RefreshWidgetIntent()) {
                HStack(spacing: 2) {
                    Text(relativeTimestamp)
                        .font(.system(size: family == .systemSmall ? 8 : 9))
                        .foregroundStyle(.tertiary)
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: family == .systemSmall ? 7 : 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var relativeTimestamp: String {
        let interval = Date().timeIntervalSince(entry.date)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        return "\(Int(interval / 86400))d"
    }

    private var titleLabel: some View {
        let title: String
        if entry.showAppName, let appName = entry.appName {
            title = appName.uppercased() + " \u{2022} " + entry.title.uppercased()
        } else {
            title = entry.title.uppercased()
        }

        return Text(title)
            .font(Font.system(size: family == .systemSmall ? 10 : 12))
            .foregroundColor(.grayColor)
            .lineLimit(1)
    }

    private var placeholderView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DAILY ACTIVE USERS")
                .padding(.top)
                .padding(.horizontal)
                .font(Font.system(size: family == .systemSmall ? 10 : 12))
                .foregroundColor(.grayColor)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.grayColor.opacity(0.2))
                .padding(.horizontal)
                .padding(.bottom)
        }
    }

    private var chooseInsightView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Select an Insight in this Widget's options")
                .multilineTextAlignment(.center)
                .font(.footnote)
                .foregroundColor(.primary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(entry.title)
                .font(.caption)
                .fontWeight(.semibold)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Button(intent: RefreshWidgetIntent()) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.telemetryOrange)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

//
//  TelemetryWidgetEntry.swift
//  TelemetryDeckWidget
//

import DataTransferObjects
import WidgetKit

struct TelemetryWidgetEntry: TimelineEntry {
    let date: Date
    let state: EntryState
    let title: String
    let appName: String?
    let showAppName: Bool
    let chartType: InsightDisplayMode?
    let appID: String?

    enum EntryState {
        case placeholder
        case chooseInsight
        case normal(query: CustomQuery, result: QueryResult)
        case error(String)
    }

    var deepLinkURL: URL? {
        guard let appID else { return nil }
        return URL(string: "telemetryviewer://insights/\(appID)")
    }

    static func placeholder() -> TelemetryWidgetEntry {
        TelemetryWidgetEntry(
            date: Date(),
            state: .placeholder,
            title: "Daily Active Users",
            appName: "Example App",
            showAppName: false,
            chartType: .barChart,
            appID: nil
        )
    }

    static func chooseInsight() -> TelemetryWidgetEntry {
        TelemetryWidgetEntry(
            date: Date(),
            state: .chooseInsight,
            title: "",
            appName: nil,
            showAppName: false,
            chartType: nil,
            appID: nil
        )
    }
}

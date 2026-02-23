//
//  TelemetryWidgetIntent.swift
//  TelemetryDeckWidget
//

import AppIntents
import WidgetKit

struct TelemetryWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configure Telemetry Widget"
    static var description: IntentDescription = "Select an insight to display"

    @Parameter(title: "App")
    var app: TelemetryAppEntity?

    @Parameter(title: "Dashboard")
    var dashboard: TelemetryDashboardEntity?

    @Parameter(title: "Insight")
    var insight: TelemetryInsightEntity?

    @Parameter(title: "Time Range (Days)", default: 30)
    var timeRangeDays: Int

    @Parameter(title: "Show App Name", default: false)
    var showAppName: Bool
}

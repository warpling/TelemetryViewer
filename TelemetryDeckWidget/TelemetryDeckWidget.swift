//
//  TelemetryDeckWidget.swift
//  TelemetryDeckWidget
//
//  Created by Charlotte Bohm on 05.10.21.
//

import DataTransferObjects
import SwiftUI
import WidgetKit

@main
struct TelemetryDeckWidget: Widget {
    let kind: String = "TelemetryDeckWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TelemetryWidgetIntent.self, provider: TelemetryWidgetProvider()) { entry in
            TelemetryDeckWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.cardBackground
                }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Telemetry Deck Widget")
        .description("Display an insight from your TelemetryDeck analytics. Select an App, Dashboard, then Insight.")
    }
}

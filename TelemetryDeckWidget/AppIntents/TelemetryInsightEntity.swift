//
//  TelemetryInsightEntity.swift
//  TelemetryDeckWidget
//

import AppIntents
import DataTransferObjects

struct TelemetryInsightEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Insight")
    static var defaultQuery = TelemetryInsightEntityQuery()

    var id: String
    var name: String
    var dashboardID: String
    var chartType: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(chartType.uppercased())")
    }
}

//
//  TelemetryDashboardEntity.swift
//  TelemetryDeckWidget
//

import AppIntents

struct TelemetryDashboardEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Dashboard")
    static var defaultQuery = TelemetryDashboardEntityQuery()

    var id: String
    var name: String
    var appID: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

//
//  TelemetryAppEntity.swift
//  TelemetryDeckWidget
//

import AppIntents

struct TelemetryAppEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "App")
    static var defaultQuery = TelemetryAppEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

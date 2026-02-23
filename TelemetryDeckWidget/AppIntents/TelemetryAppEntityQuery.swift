//
//  TelemetryAppEntityQuery.swift
//  TelemetryDeckWidget
//

import AppIntents
import DataTransferObjects

struct TelemetryAppEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TelemetryAppEntity] {
        let allApps = try await fetchApps()
        return allApps.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [TelemetryAppEntity] {
        try await fetchApps()
    }

    private func fetchApps() async throws -> [TelemetryAppEntity] {
        let api = APIClient()
        let url = api.urlForPath(apiVersion: .v3, "apps")
        let apps: [AppInfo] = try await api.get(url: url)
        return apps
            .sorted { $0.name < $1.name }
            .map { TelemetryAppEntity(id: $0.id.uuidString, name: $0.name) }
    }
}

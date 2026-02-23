//
//  TelemetryDashboardEntityQuery.swift
//  TelemetryDeckWidget
//

import AppIntents
import DataTransferObjects

struct TelemetryDashboardEntityQuery: EntityQuery {
    @IntentParameterDependency<TelemetryWidgetIntent>(\.$app)
    var widgetIntent

    func entities(for identifiers: [String]) async throws -> [TelemetryDashboardEntity] {
        let all = try await fetchDashboards()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [TelemetryDashboardEntity] {
        try await fetchDashboards()
    }

    private func fetchDashboards() async throws -> [TelemetryDashboardEntity] {
        guard let intent = widgetIntent,
              let appID = UUID(uuidString: intent.app.id) else {
            return []
        }

        let api = APIClient()
        let url = api.urlForPath(apiVersion: .v3, "apps")
        let apps: [AppInfo] = try await api.get(url: url)

        guard let matchedApp = apps.first(where: { $0.id == appID }) else {
            return []
        }

        return matchedApp.insightGroups
            .sorted { ($0.order ?? 0) < ($1.order ?? 0) }
            .map { TelemetryDashboardEntity(id: $0.id.uuidString, name: $0.title, appID: intent.app.id) }
    }
}

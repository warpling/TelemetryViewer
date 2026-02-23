//
//  TelemetryInsightEntityQuery.swift
//  TelemetryDeckWidget
//

import AppIntents
import DataTransferObjects

struct TelemetryInsightEntityQuery: EntityQuery {
    @IntentParameterDependency<TelemetryWidgetIntent>(\.$app, \.$dashboard)
    var widgetIntent

    func entities(for identifiers: [String]) async throws -> [TelemetryInsightEntity] {
        // For resolving specific entities, always try network first, then cache
        if let fresh = try? await fetchInsights() {
            return fresh.filter { identifiers.contains($0.id) }
        }
        let cacheKey = cacheKeyForCurrentDashboard
        if let cached = Self.loadCached(key: cacheKey) {
            return cached.filter { identifiers.contains($0.id) }
        }
        return []
    }

    func suggestedEntities() async throws -> [TelemetryInsightEntity] {
        let cacheKey = cacheKeyForCurrentDashboard

        // If we have cached results, return them immediately
        // and refresh cache in the background for next time
        if let cached = Self.loadCached(key: cacheKey) {
            Task {
                if let fresh = try? await fetchInsights() {
                    Self.saveCache(entities: fresh, key: cacheKey)
                }
            }
            return cached
        }

        // No cache — must fetch (first time for this dashboard)
        let fresh = try await fetchInsights()
        Self.saveCache(entities: fresh, key: cacheKey)
        return fresh
    }

    private var cacheKeyForCurrentDashboard: String {
        guard let intent = widgetIntent else { return "cached_insights_none" }
        return "cached_insights_\(intent.dashboard.id)"
    }

    private func fetchInsights() async throws -> [TelemetryInsightEntity] {
        guard let intent = widgetIntent else {
            return []
        }

        let api = APIClient()
        let url = api.urlForPath(apiVersion: .v3, "groups", intent.dashboard.id)
        let group: InsightGroupInfo = try await api.get(url: url)

        guard let insights = group.insights else {
            return []
        }

        return insights
            .sorted { ($0.order ?? 0) < ($1.order ?? 0) }
            .map {
                TelemetryInsightEntity(
                    id: $0.id.uuidString,
                    name: $0.title,
                    dashboardID: intent.dashboard.id,
                    chartType: $0.displayMode.rawValue
                )
            }
    }

    // MARK: - Simple UserDefaults cache

    private static let defaults = UserDefaults(suiteName: "group.\(Bundle.main.infoDictionary?["DeveloperBundleID"] as? String ?? "com.telemetrydeck").shared")

    private static func saveCache(entities: [TelemetryInsightEntity], key: String) {
        let dicts = entities.map { [
            "id": $0.id,
            "name": $0.name,
            "dashboardID": $0.dashboardID,
            "chartType": $0.chartType
        ] }
        defaults?.set(dicts, forKey: key)
    }

    private static func loadCached(key: String) -> [TelemetryInsightEntity]? {
        guard let dicts = defaults?.array(forKey: key) as? [[String: String]] else {
            return nil
        }
        return dicts.compactMap { dict in
            guard let id = dict["id"],
                  let name = dict["name"],
                  let dashboardID = dict["dashboardID"],
                  let chartType = dict["chartType"] else { return nil }
            return TelemetryInsightEntity(id: id, name: name, dashboardID: dashboardID, chartType: chartType)
        }
    }
}

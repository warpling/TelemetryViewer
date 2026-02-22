//
//  TelemetryWidgetProvider.swift
//  TelemetryDeckWidget
//

import DataTransferObjects
import SwiftUI
import WidgetKit

#if canImport(TelemetryClient)
import TelemetryClient
#endif

struct TelemetryWidgetProvider: AppIntentTimelineProvider {
    let api: APIClient

    init() {
        #if canImport(TelemetryClient)
        let configuration = TelemetryManagerConfiguration(appID: "79167A27-EBBF-4012-9974-160624E5D07B")
        TelemetryManager.initialize(with: configuration)
        #endif

        self.api = APIClient()
    }

    func placeholder(in context: Context) -> TelemetryWidgetEntry {
        .placeholder()
    }

    func snapshot(for configuration: TelemetryWidgetIntent, in context: Context) async -> TelemetryWidgetEntry {
        TelemetryWidgetEntry(
            date: Date(),
            state: .normal(query: mockBarQuery, result: .timeSeries(mockTimeSeriesResult)),
            title: "Daily Active Users",
            appName: "My App",
            showAppName: false,
            chartType: .barChart,
            appID: configuration.app?.id
        )
    }

    func timeline(for configuration: TelemetryWidgetIntent, in context: Context) async -> Timeline<TelemetryWidgetEntry> {
        let nextUpdate = Date().addingTimeInterval(Timing.widgetRefreshInterval)

        guard let insightEntity = configuration.insight,
              let insightID = UUID(uuidString: insightEntity.id) else {
            let entry = TelemetryWidgetEntry.chooseInsight()
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        }

        do {
            let (query, result, displayMode) = try await fetchInsightData(
                insightID: insightID,
                timeRangeDays: configuration.timeRangeDays
            )

            let title = insightEntity.name
            let appName = configuration.app?.name

            let entry = TelemetryWidgetEntry(
                date: Date(),
                state: .normal(query: query, result: result),
                title: title,
                appName: appName,
                showAppName: configuration.showAppName,
                chartType: displayMode,
                appID: configuration.app?.id
            )

            #if canImport(TelemetryClient)
            TelemetryManager.send("WidgetReloaded", with: [
                "WidgetChartType": displayMode.rawValue,
                "WidgetSize": context.family.description
            ])
            #endif

            return Timeline(entries: [entry], policy: .after(nextUpdate))
        } catch {
            let entry = TelemetryWidgetEntry(
                date: Date(),
                state: .error(error.localizedDescription),
                title: insightEntity.name,
                appName: configuration.app?.name,
                showAppName: configuration.showAppName,
                chartType: nil,
                appID: configuration.app?.id
            )
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        }
    }

    private func fetchInsightData(
        insightID: UUID,
        timeRangeDays: Int
    ) async throws -> (CustomQuery, QueryResult, InsightDisplayMode) {
        // First get the insight definition to obtain its query and display mode
        let insightURL = api.urlForPath(apiVersion: .v3, "insights", insightID.uuidString)
        let insight: DTOv2.Insight = try await api.get(url: insightURL)

        guard var query = insight.customQuery else {
            throw TransferError.decodeFailed
        }

        // Set the time interval if not already set
        let days = max(1, min(300, timeRangeDays))
        let endDate = Date()
        let beginDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate

        if query.relativeIntervals == nil && query.intervals == nil {
            query.relativeIntervals = [
                RelativeTimeInterval(
                    beginningDate: RelativeDate(.beginning, of: .day, adding: -days),
                    endDate: RelativeDate(.end, of: .day, adding: 0)
                )
            ]
        }

        // Start async calculation
        let queryBeginURL = api.urlForPath(apiVersion: .v3, "query", "calculate-async")
        let response: [String: String] = try await api.post(data: query, url: queryBeginURL)
        guard let taskID = response["queryTaskID"] else {
            throw TransferError.decodeFailed
        }

        // Poll for completion (up to 25 seconds for widget timeline limit)
        let deadline = Date().addingTimeInterval(25)
        var taskStatus: QueryTaskStatus = .running

        while taskStatus != .successful && Date() < deadline {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let statusURL = api.urlForPath(apiVersion: .v3, "task", taskID, "status")

            do {
                let status: QueryTaskStatusStruct = try await api.get(url: statusURL)
                taskStatus = status.status
            } catch TransferError.decodeFailed {
                // API may return a status value not in our enum (e.g. "queued").
                // Treat as still in progress and keep polling.
            }

            if taskStatus == .error {
                throw TransferError.serverError(message: "Query calculation failed")
            }
        }

        // Get the result
        let resultURL = api.urlForPath(apiVersion: .v3, "task", taskID, "lastSuccessfulValue")
        let wrapper: QueryResultWrapper = try await api.get(url: resultURL)

        guard let result = wrapper.result else {
            throw TransferError.decodeFailed
        }

        return (query, result, insight.displayMode)
    }
}

//
//  QueryRunner.swift
//  Telemetry Viewer (iOS)
//
//  Created by Lukas on 23.05.24.
//

import Combine
import DataTransferObjects
import SwiftUI

struct QueryRunner: View {
    @EnvironmentObject var api: APIClient
    @EnvironmentObject var queryService: QueryService

    let query: CustomQuery
    let title: String
    let type: InsightDisplayMode
    var initialLoadDelay: TimeInterval = 0

    @Environment(\.scenePhase) private var scenePhase

    @State var queryResultWrapper: QueryResultWrapper?
    @State var isLoading: Bool = false
    @State var taskID: String = ""
    @State var errorMessage: String?
    @State private var isStale: Bool = false
    @State private var isCachedResult: Bool = false
    @State private var activeQueryTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 10){
            if let queryResult = queryResultWrapper?.result {
                ClusterChart(query: query, result: queryResult, title: title, type: type)
                    .frame(height: Self.chartHeight(for: type, result: queryResult))
                    .id(queryResultWrapper)
                    .padding(.horizontal)
                    .saturation(isCachedResult ? 0.1 : 1.0)
                    .opacity(isCachedResult ? 0.4 : 1.0)
            } else if errorMessage != nil || queryResultWrapper?.error != nil {
                DashboardLink()
                    .padding()
            } else {
                SondrineAnimation()
                    .frame(width: 100, height: 100)
                    .opacity(0.5)
                    .padding()
            }

            HStack(spacing: 3) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.75)
                        .frame(height: 5)
                }
                Spacer()
                if let queryResultWrapper = queryResultWrapper, queryResultWrapper.result != nil {
                    Button {
                        Task { await runQuery() }
                    } label: {
                        RelativeTimestampLabel(date: queryResultWrapper.calculationFinishedAt, showRefreshIcon: isStale)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                } else if errorMessage != nil || queryResultWrapper?.error != nil {
                    Button {
                        Task { await runQuery() }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise")
                            Text("Failed — Tap to retry")
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                } else {
                    Text("Calculating...")
                }
            }
            .font(.footnote)
            .foregroundStyle(Color.Zinc400)
            .padding(8)
            .background(Color.Zinc50)
        }
        .onAppear {
            if queryResultWrapper == nil,
               let cached = DiskCache.load(QueryResultWrapper.self, forKey: cacheKey()) {
                queryResultWrapper = cached
                isCachedResult = true
            }
            activeQueryTask = Task {
                if initialLoadDelay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(initialLoadDelay * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                }
                await runQuery()
            }
        }
        .onChange(of: queryService.isTestingMode) { _, _ in
            activeQueryTask?.cancel()
            activeQueryTask = Task {
                await runQuery()
            }
        }
        .onChange(of: queryService.timeWindowBeginning) { _, _ in
            #if DEBUG
            print("📅 [\(title)] timeWindowBeginning changed → \(queryService.timeWindowBeginning)")
            #endif
            activeQueryTask?.cancel()
            queryResultWrapper = nil
            activeQueryTask = Task {
                await runQuery()
            }
        }
        .onChange(of: queryService.timeWindowEnd) { _, _ in
            #if DEBUG
            print("📅 [\(title)] timeWindowEnd changed → \(queryService.timeWindowEnd)")
            #endif
            activeQueryTask?.cancel()
            queryResultWrapper = nil
            activeQueryTask = Task {
                await runQuery()
            }
        }
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            updateStaleness()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, !isLoading,
               let wrapper = queryResultWrapper,
               Date().timeIntervalSince(wrapper.calculationFinishedAt) > Timing.queryAutoRefreshThreshold {
                activeQueryTask?.cancel()
                activeQueryTask = Task { await runQuery() }
            }
        }
    }

    private func runQuery() async {
        do {
            errorMessage = nil
            #if DEBUG
            print("📊 [\(title)] runQuery: \(queryService.timeWindowBeginning) → \(queryService.timeWindowEnd)")
            #endif
            try await getQueryResult()
            isCachedResult = false
            #if DEBUG
            if let wrapper = queryResultWrapper, let result = wrapper.result {
                switch result {
                case .timeSeries(let ts):
                    let dates = ts.rows.map { $0.timestamp }
                    print("✅ [\(title)] got \(ts.rows.count) rows: \(dates.first.map { ChartTooltip.formatDate($0) } ?? "?") → \(dates.last.map { ChartTooltip.formatDate($0) } ?? "?")")
                case .topN(let tn):
                    let dates = tn.rows.map { $0.timestamp }
                    print("✅ [\(title)] got \(tn.rows.count) rows: \(dates.first.map { ChartTooltip.formatDate($0) } ?? "?") → \(dates.last.map { ChartTooltip.formatDate($0) } ?? "?")")
                default:
                    print("✅ [\(title)] got result type: \(result)")
                }
            }
            #endif
            if let wrapper = queryResultWrapper {
                DiskCache.save(wrapper, forKey: cacheKey())
            }
            updateStaleness()
        } catch is CancellationError {
            #if DEBUG
            print("🚫 [\(title)] query cancelled")
            #endif
        } catch {
            errorMessage = "Could not load data"
            print(error)
        }
    }

    private func cacheKey() -> String {
        let effectiveQuery = queryWithUserDates()
        guard let data = try? JSONEncoder.telemetryEncoder.encode(effectiveQuery) else { return "chart_unknown" }
        // Stable djb2 hash from the encoded query data
        var hash: UInt64 = 5381
        for byte in data {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return "chart_\(hash)"
    }

    private static let defaultChartHeight: CGFloat = 135
    private static let maxChartHeight: CGFloat = 270

    private static func chartHeight(for type: InsightDisplayMode, result: QueryResult) -> CGFloat {
        switch type {
        case .funnelChart:
            if case .groupBy(let gbResult) = result,
               let firstRow = gbResult.rows.first {
                let stepCount = firstRow.event.metrics.filter { $0.key.first?.isNumber == true }.count
                let needed = CGFloat(stepCount) * 26 + CGFloat(max(0, stepCount - 1)) * 2
                return min(max(needed, defaultChartHeight), maxChartHeight)
            }
            return defaultChartHeight
        case .raw:
            return defaultChartHeight
        default:
            return defaultChartHeight
        }
    }

    private func updateStaleness() {
        guard let wrapper = queryResultWrapper else {
            isStale = false
            return
        }
        isStale = Date().timeIntervalSince(wrapper.calculationFinishedAt) > Timing.queryStaleThreshold
    }

    private func getQueryResult() async throws {
        isLoading = true
        defer {
            if !Task.isCancelled {
                isLoading = false
            }
        }

        taskID = try await beginAsyncCalcV2()

        try Task.checkCancellation()

        try await waitUntilTaskStatusIsSuccessful(taskID)

        try Task.checkCancellation()

        try await getLastSuccessfulValue(taskID)
    }
}

extension QueryRunner {

    private func queryWithUserDates() -> CustomQuery {
        var queryCopy = query
        switch queryService.timeWindowBeginning {
        case .absolute:
            queryCopy.relativeIntervals = nil
            queryCopy.intervals = [.init(beginningDate: queryService.timeWindowBeginningDate, endDate: queryService.timeWindowEndDate)]
        default:
            queryCopy.intervals = nil
            queryCopy.relativeIntervals = [RelativeTimeInterval(
                beginningDate: queryService.timeWindowBeginning.toRelativeDate(),
                endDate: queryService.timeWindowEnd.toRelativeDate()
            )]
        }
        if queryCopy.testMode == nil {
            queryCopy.testMode = queryService.isTestingMode
        }
        return queryCopy
    }

    private func beginAsyncCalcV2() async throws -> String {
        // create a query task
        let queryBeginURL = api.urlForPath(apiVersion: .v3, "query", "calculate-async")

        let queryCopy = queryWithUserDates()

        let response: [String: String] = try await api.post(data: queryCopy, url: queryBeginURL)
        guard let taskID = response["queryTaskID"] else {
            throw TransferError.decodeFailed
        }

        return taskID
    }

    private func getLastSuccessfulValue(_ taskID: String) async throws {
        // pick up the finished result
        let lastSuccessfulValueURL = api.urlForPath(apiVersion: .v3, "task", taskID, "lastSuccessfulValue")
        queryResultWrapper = try await api.get(url: lastSuccessfulValueURL)
    }

    private func waitUntilTaskStatusIsSuccessful(_ taskID: String) async throws {
        // wait for the task to finish calculating
        var taskStatus: QueryTaskStatus = .running
        while taskStatus != .successful {
            try Task.checkCancellation()

            let taskStatusURL = api.urlForPath(apiVersion: .v3, "task", taskID, "status")

            do {
                let queryTaskStatus: QueryTaskStatusStruct = try await api.get(url: taskStatusURL)
                taskStatus = queryTaskStatus.status
            } catch TransferError.decodeFailed {
                // API may return a status value not in our enum (e.g. "queued").
                // Treat as still in progress and keep polling.
            }

            if taskStatus == .error {
                throw TransferError.serverError(message: "The server returned an error")
            }

            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
}

private struct RelativeTimestampLabel: View {
    let date: Date
    let showRefreshIcon: Bool

    var body: some View {
        TimelineView(PeriodicTimelineSchedule(from: .now, by: 60)) { context in
            HStack(spacing: 3) {
                if showRefreshIcon {
                    Image(systemName: "arrow.clockwise")
                }
                Text(Self.relativeTimeLabel(from: date, to: context.date))
            }
        }
    }

    private static let formatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.day, .hour, .minute]
        f.unitsStyle = .short
        f.maximumUnitCount = 1
        return f
    }()

    private static func relativeTimeLabel(from date: Date, to now: Date) -> String {
        let interval = max(60, now.timeIntervalSince(date))
        if let str = formatter.string(from: interval) {
            return "Updated \(str) ago"
        }
        return "Updated just now"
    }
}

extension RelativeDateDescription {
    func toRelativeDate() -> RelativeDate{
        switch self {
        case .end(let of):
            switch of {
            case .current(let calendarComponent):
                return RelativeDate(.end, of: RelativeDate.RelativeDateComponent.from(calenderComponent: calendarComponent), adding: 0)
            case .previous(let calendarComponent):
                return RelativeDate(.end, of: RelativeDate.RelativeDateComponent.from(calenderComponent: calendarComponent), adding: -1)
            }
        case .beginning(let of):
            switch of {
            case .current(let calendarComponent):
                return RelativeDate(.beginning, of: RelativeDate.RelativeDateComponent.from(calenderComponent: calendarComponent), adding: 0)
            case .previous(let calendarComponent):
                return RelativeDate(.beginning, of: RelativeDate.RelativeDateComponent.from(calenderComponent: calendarComponent), adding: -1)
            }
        case .goBack(let days):
            return RelativeDate(.beginning, of: .day, adding: -days)
        case .absolute:
            assertionFailure(".absolute dates should use QueryTimeInterval, not toRelativeDate()")
            return RelativeDate(.beginning, of: .day, adding: -30)
        }
    }
}

extension RelativeDate.RelativeDateComponent {
    static func from (calenderComponent: Calendar.Component) -> Self {
        switch calenderComponent {
        case .hour:
                .hour
        case .day:
                .day
        case .weekOfYear:
                .week
        case .month:
                .month
        case .quarter:
                .quarter
        case .year:
                .year
        default:
                .day
        }
    }
}

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

    @Environment(\.scenePhase) private var scenePhase

    @State var queryResultWrapper: QueryResultWrapper?
    @State var isLoading: Bool = false
    @State var taskID: String = ""
    @State var errorMessage: String?
    @State private var isStale: Bool = false

    var body: some View {
        VStack(spacing: 10){
            if let queryResult = queryResultWrapper?.result {
                ClusterChart(query: query, result: queryResult, title: title, type: type)
                    .frame(height: 135)
                    .id(queryResultWrapper)
                    .padding(.horizontal)
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
                        HStack(spacing: 3) {
                            if isStale {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Updated")
                            Text(queryResultWrapper.calculationFinishedAt, style: .relative)
                            Text("ago")
                        }
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
            Task {
                await runQuery()
            }
        }
        .onChange(of: queryService.isTestingMode) { _ in
            Task {
                await runQuery()
            }
        }
        .onChange(of: queryService.timeWindowBeginning) { _ in
            Task {
                await runQuery()
            }
        }
        .onChange(of: queryService.timeWindowEnd) { _ in
            Task {
                await runQuery()
            }
        }
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            updateStaleness()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active, !isLoading,
               let wrapper = queryResultWrapper,
               Date().timeIntervalSince(wrapper.calculationFinishedAt) > Timing.queryAutoRefreshThreshold {
                Task { await runQuery() }
            }
        }
    }

    private func runQuery() async {
        do {
            errorMessage = nil
            try await getQueryResult()
            updateStaleness()
        } catch {
            errorMessage = "Could not load data"
            print(error)
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
            isLoading = false
        }

        taskID = try await beginAsyncCalcV2()

        try await getLastSuccessfulValue(taskID)

        try await waitUntilTaskStatusIsSuccessful(taskID)

        try await getLastSuccessfulValue(taskID)
    }
}

extension QueryRunner {

    private func beginAsyncCalcV2() async throws -> String {
        // create a query task
        let queryBeginURL = api.urlForPath(apiVersion: .v3, "query", "calculate-async")

        var queryCopy = query

        if queryCopy.intervals == nil && queryCopy.relativeIntervals == nil{
            switch queryService.timeWindowBeginning {
            case .absolute:
                queryCopy.intervals = [.init(beginningDate: queryService.timeWindowBeginningDate, endDate: queryService.timeWindowEndDate)]
            default:
                queryCopy.relativeIntervals = [RelativeTimeInterval(beginningDate: queryService.timeWindowBeginning.toRelativeDate(), endDate: queryService.timeWindowEnd.toRelativeDate())]
            }
        }
        if queryCopy.testMode == nil {
            queryCopy.testMode = queryService.isTestingMode
        }

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

extension RelativeDateDescription {
    func toRelativeDate() -> RelativeDate{
        switch self {
        case .end(let of):
            switch of {
            case .current(let calendarComponent):
                RelativeDate(.end, of: RelativeDate.RelativeDateComponent.from(calenderComponent: calendarComponent), adding: 0)
            case .previous(let calendarComponent):
                RelativeDate(.end, of: RelativeDate.RelativeDateComponent.from(calenderComponent: calendarComponent), adding: -1)
            }
        case .beginning(let of):
            switch of {
            case .current(let calendarComponent):
                RelativeDate(.beginning, of: RelativeDate.RelativeDateComponent.from(calenderComponent: calendarComponent), adding: 0)
            case .previous(let calendarComponent):
                RelativeDate(.beginning, of: RelativeDate.RelativeDateComponent.from(calenderComponent: calendarComponent), adding: -1)
            }
        case .goBack(let days):
            RelativeDate(.beginning, of: .day, adding: -days)
        case .absolute:
            RelativeDate(.beginning, of: .day, adding: -30)
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

//
//  InsightGroupsView.swift
//  InsightGroupsView
//
//  Created by Daniel Jilg on 18.08.21.
//

import DataTransferObjects
import SwiftUI
import TelemetryClient

/// Show insight groups and insights
struct InsightGroupsView: View {
    @EnvironmentObject var appService: AppService
    @EnvironmentObject var groupService: GroupService
    @EnvironmentObject var queryService: QueryService
    @EnvironmentObject var insightService: InsightService

    @State var sidebarVisible = false
    @State var selectedInsightGroupID: DTOv2.Group.ID?
    @State var selectedInsightID: DTOv2.Insight.ID?
    @State private var showDatePicker: Bool = false

    @Environment(\.horizontalSizeClass) var sizeClass

    let appID: DTOv2.App.ID

    private var selectedGroupTitle: String {
        guard let groupID = selectedInsightGroupID else { return "Dashboard" }
        return groupService.group(withID: groupID)?.title ?? "Dashboard"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusMessageDisplay()

            // Group selector header
            groupSelectorHeader
                .padding(.horizontal)
                .padding(.top, 8)

            if queryService.isTestingMode {
                TestModeIndicator()
            }

            Divider()

            Group {
                if selectedInsightGroupID == nil {
                    EmptyAppView(appID: appID)
                        .frame(maxWidth: 400)
                        .padding()
                }

                selectedInsightGroupID.map {
                    GroupView(groupID: $0, selectedInsightID: $selectedInsightID, sidebarVisible: $sidebarVisible)
                        .background(Color.Zinc100)
                }
            }
        }
        .navigationTitle(appService.app(withID: appID)?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                datePickerButton
            }
        }
        .onAppear {
            selectedInsightGroupID = appService.app(withID: appID)?.insightGroupIDs.first
            TelemetryManager.send("InsightGroupsAppear")
        }
        .task(id: selectedInsightGroupID) {
            guard let groupID = selectedInsightGroupID else { return }
            for insightID in groupService.groupsDictionary[groupID]?.insightIDs ?? [] {
                if !(insightService.insightDictionary.keys.contains(insightID)) {
                    await insightService.retrieveInsight(with: insightID)
                }
            }
        }
        .onReceive(groupService.objectWillChange) { _ in
            if let groupID = selectedInsightGroupID {
                if !(groupService.groupsDictionary.keys.contains(groupID)) {
                    selectedInsightGroupID = appService.appDictionary[appID]?.insightGroupIDs.first
                }
            } else {
                selectedInsightGroupID = appService.appDictionary[appID]?.insightGroupIDs.first
            }
        }
    }

    private var groupSelectorHeader: some View {
        Menu {
            if let app = appService.app(withID: appID) {
                ForEach(
                    app.insightGroupIDs
                        .map { ($0, groupService.group(withID: $0)?.order ?? 0) }
                        .sorted(by: { $0.1 < $1.1 }),
                    id: \.0
                ) { idTuple in
                    Button {
                        selectedInsightGroupID = idTuple.0
                    } label: {
                        HStack {
                            Text(groupService.group(withID: idTuple.0)?.title ?? "Loading...")
                            if idTuple.0 == selectedInsightGroupID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            Toggle("Test Mode", isOn: $queryService.isTestingMode.animation())
        } label: {
            HStack(spacing: 4) {
                Text(selectedGroupTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
    }

    private var datePickerButton: some View {
        Button(queryService.timeIntervalDescription) {
            TelemetryManager.send("showDatePicker")
            self.showDatePicker = true
        }.popover(
            isPresented: self.$showDatePicker,
            arrowEdge: .bottom
        ) { InsightDataTimeIntervalPicker().padding() }
    }

    private var newGroupButton: some View {
        Button {
            groupService.create(insightGroupNamed: "New Group", for: appID) { _ in
                Task {
                    if let app = try? await appService.retrieveApp(withID: appID) {
                        DispatchQueue.main.async {
                            appService.appDictionary[appID] = app
                            appService.app(withID: appID)?.insightGroupIDs.forEach { groupID in
                                groupService.retrieveGroup(with: groupID)
                            }
                        }
                    }
                }
            }
        } label: {
            Label("New Group", systemImage: "plus")
        }
    }
}

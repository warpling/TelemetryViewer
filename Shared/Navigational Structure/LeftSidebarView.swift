//
//  LeftSidebarView.swift
//  Telemetry Viewer
//
//  Created by Daniel Jilg on 17.02.21.
//

import DataTransferObjects
import SwiftUI

struct LeftSidebarView: View {
    @EnvironmentObject var api: APIClient
    @EnvironmentObject var orgService: OrgService
    @EnvironmentObject var appService: AppService
    @EnvironmentObject var groupService: GroupService
    @EnvironmentObject var insightService: InsightService
    @State private var showingAlert = false
    @State private var showingOrgSheet = false
    @State private var currentOrgName: String?

    #if os(macOS)
        @EnvironmentObject var updateService: UpdateService
    #endif

    // swiftlint:disable:next redundant_optional_initialization
    @AppStorage("sidebarSelectionExpandedSections") var expandedSections: [DTOv2.App.ID: Bool]? = nil

    @Binding var sidebarSelection: Selection?

    enum Selection: Codable, Hashable {
        case getStarted
        case plansAndPricing
        case feedback
        case newApp
        case insights(app: UUID)
        case signalTypes(app: UUID)
        case recentSignals(app: UUID)
        case editApp(app: UUID)
    }

    func loadApps() {
        Task {
            guard let apps = try? await appService.allApps() else { return }
            DispatchQueue.main.async {
                for app in apps {
                    app.insightGroupIDs.forEach { groupID in
                        if !(groupService.groupsDictionary.keys.contains(groupID)) {
                            groupService.retrieveGroup(with: groupID)
                        }
                    }
                    appService.appDictionary[app.id] = app
                }
                appService.saveAppsToDisk()
            }
        }
    }

    var body: some View {
        List(selection: $sidebarSelection) {
            Section {
                ForEach(Array(appService.appDictionary.keys), id: \.self) { appID in
                    section(for: appID)
                }
            } header: {
                Text("Apps")
            }

        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showingOrgSheet = true
            } label: {
                HStack {
                    Text(currentOrgName ?? "Organization")
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
        .sheet(isPresented: $showingOrgSheet) {
            orgSheet
        }
        .task {
            // Ensure an org is selected (required for td-organization-id header)
            let orgs = (try? await orgService.allOrganizations()) ?? []
            if !orgs.isEmpty {
                let hasValidSelection = orgs.contains { $0.id.uuidString == api._currentOrganisationID }
                if !hasValidSelection {
                    api._currentOrganisationID = orgs.first?.id.uuidString
                }
                currentOrgName = orgs.first(where: { $0.id.uuidString == api._currentOrganisationID })?.name
                    ?? orgs.first?.name
            }

            // Load apps directly from v3 endpoint
            loadApps()
        }

        #if os(macOS)
            .sheet(isPresented: $updateService.shouldShowUpdateNowScreen) {
                AppUpdateView()
            }
        #endif
            .navigationTitle("TelemetryDeck")
            .listStyle(.sidebar)
            .toolbar {
                ToolbarItemGroup {
                    #if os(macOS)
                        Button(action: toggleSidebar) {
                            Image(systemName: "sidebar.left")
                                .help("Toggle Sidebar")
                        }
                        .help("Toggle the left sidebar")

                        Spacer()
                    #endif
                }
            }
    }

    private func binding(for key: DTOv2.App.ID) -> Binding<Bool> {
        return .init(
            get: { self.expandedSections?[key] ?? false },
            set: {
                if self.expandedSections == nil {
                    self.expandedSections = [:]
                }
                self.expandedSections?[key] = $0
            }
        )
    }

    func section(for appID: DTOv2.App.ID) -> some View {
        DisclosureGroup(isExpanded: self.binding(for: appID)) {
            if let app = appService.appDictionary[appID] {
                NavigationLink(value: Selection.insights(app: app.id)) {
                    Label("Insights", systemImage: "chart.bar.xaxis")
                }

                NavigationLink(value: Selection.signalTypes(app: app.id)) {
                    Label("Signal Types", systemImage: "book")
                }

                NavigationLink(value: Selection.recentSignals(app: app.id)) {
                    Label("Recent Signals", systemImage: "list.triangle")
                }

            } else {
                TinyLoadingStateIndicator(loadingState: appService.loadingStateDictionary[appID] ?? .idle, title: "Insights")
                TinyLoadingStateIndicator(loadingState: appService.loadingStateDictionary[appID] ?? .idle, title: "Signal Types")
                TinyLoadingStateIndicator(loadingState: appService.loadingStateDictionary[appID] ?? .idle, title: "Recent Signals")
            }
        } label: {
            TinyLoadingStateIndicator(loadingState: appService.loadingStateDictionary[appID] ?? .idle, title: appService.appDictionary[appID]?.name)
        }
    }

    private var orgSheet: some View {
        NavigationStack {
            List {
                Section {
                    OrganisationSwitcher()
                }

                Section {
                    #if os(iOS)
                    Button {
                        URL(string: "https://dashboard.telemetrydeck.com/user/organization")!.open()
                    } label: {
                        HStack {
                            Label("Organization Settings", systemImage: "app.badge")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.gray)
                        }
                    }

                    if api.user != nil {
                        Button {
                            URL(string: "https://dashboard.telemetrydeck.com/user/profile")!.open()
                        } label: {
                            HStack {
                                Label("User Settings", systemImage: "gear")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    #endif

                    Button {
                        showingOrgSheet = false
                        sidebarSelection = .feedback
                    } label: {
                        Label("Help & Feedback", systemImage: "ladybug.fill")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingAlert = true
                    } label: {
                        Label("Log Out \(api.user?.firstName ?? "User")", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle(currentOrgName ?? "Organization")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingOrgSheet = false }
                }
            }
            .alert("Really Log Out?", isPresented: $showingAlert) {
                Button("Log Out", role: .destructive) {
                    showingOrgSheet = false
                    api.logout()
                    orgService.organization = nil
                    appService.appDictionary = [:]
                    groupService.groupsDictionary = [:]
                    insightService.insightDictionary = [:]
                    appService.clearCache()
                    DiskCache.clear()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can log back in again later")
            }
        }
    }

    #if os(macOS)
        private func toggleSidebar() {
            NSApp.keyWindow?.firstResponder?
                .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
        }
    #endif
}

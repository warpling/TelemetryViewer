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
    @State private var showingHelpSheet = false
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
            #if os(macOS)
            .popover(isPresented: $showingOrgSheet, arrowEdge: .top) {
                orgSheet
            }
            #endif
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
        #if os(iOS)
        .sheet(isPresented: $showingOrgSheet) {
            orgSheet
        }
        #endif
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

        .sheet(isPresented: $showingHelpSheet) {
            FeedbackView()
                #if os(macOS)
                .frame(minWidth: 500, minHeight: 400)
                #endif
        }
        #if os(macOS)
            .sheet(isPresented: $updateService.shouldShowUpdateNowScreen) {
                AppUpdateView()
            }
        #endif
            #if os(iOS)
            .navigationTitle("TelemetryDeck")
            #endif
            .listStyle(.sidebar)
            .toolbar {
                ToolbarItemGroup {
                    #if os(macOS)
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
        #if os(macOS)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                OrganisationSwitcher()
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                Divider().padding(.horizontal)

                Button {
                    showingOrgSheet = false
                    showingHelpSheet = true
                } label: {
                    Label("Help & Feedback", systemImage: "ladybug.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider().padding(.horizontal)

                Button {
                    showingAlert = true
                } label: {
                    Label("Log Out \(api.user?.firstName ?? "User")", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .padding(.vertical, 4)
        }
        .frame(minWidth: 260)
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
        #else
        NavigationStack {
            List {
                Section {
                    OrganisationSwitcher()
                }

                Section {
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
            .navigationBarTitleDisplayMode(.inline)
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
        #endif
    }


}

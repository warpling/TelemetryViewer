//
//  RootView.swift
//  Telemetry Viewer
//
//  Created by Daniel Jilg on 04.09.20.
//

import DataTransferObjects
import SwiftUI
import WidgetKit

struct RootView: View {
    @EnvironmentObject var api: APIClient
    @EnvironmentObject var orgService: OrgService
    @EnvironmentObject var appService: AppService

    // swiftlint:disable:next redundant_optional_initialization
    @AppStorage("sidebarSelection") var sidebarSelection: LeftSidebarView.Selection? = nil

    var body: some View {
        if api.userNotLoggedIn {
            #if os(iOS)
            WelcomeView()

            #else
            HStack {
                Spacer()
                WelcomeView()
                    .frame(maxWidth: 600)
                    .alert(isPresented: $api.userLoginFailed, content: loginFailedView)
                Spacer()
            }
            #endif
        } else {
            NavigationSplitView {
                LeftSidebarView(sidebarSelection: $sidebarSelection)
            } detail: {
                NavigationStack {
                    switch sidebarSelection {
                    case .insights(let appID):
                        InsightGroupsView(appID: appID)
                    case .signalTypes(let appID):
                        LexiconView(appID: appID)
                    case .recentSignals(let appID):
                        SignalList(appID: appID)
                    case .feedback:
                        FeedbackView()
                    case .getStarted, .plansAndPricing, .newApp, .editApp, nil:
                        NoAppSelectedView()
                    }
                }
                .id(sidebarSelection)
            }
            .alert(isPresented: $api.userLoginFailed, content: loginFailedView)
            .onAppear {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    func loginFailedView() -> Alert {
        Alert(
            title: Text("Login Failed"),
            message: Text("TelemetryDeck could not connect to the server. Please check your internet connection. \(api.userLoginErrorMessage != nil ? api.userLoginErrorMessage! : "")"),
            primaryButton: .default(Text("Reload")) {
                api.getUserInformation()
            },
            secondaryButton: .destructive(Text("Log Out")) {
                api.logout()
            }
        )
    }
}

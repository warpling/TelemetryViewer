//
//  AppConstants.swift
//  Telemetry Viewer
//

import Foundation

enum Timing {
    // MARK: - Cache TTLs
    /// How long organization data stays in memory cache
    static let organizationCacheTTL: TimeInterval = 20 * 60       // 20 min
    /// How long app data stays in memory cache
    static let appCacheTTL: TimeInterval = 20 * 60                // 20 min
    /// How long insight group data stays in memory cache
    static let groupCacheTTL: TimeInterval = 10 * 60              // 10 min
    /// How long insight definitions stay in memory cache
    static let insightCacheTTL: TimeInterval = 5 * 60             // 5 min
    /// How long insight calculation results stay in memory cache
    static let insightResultCacheTTL: TimeInterval = 20 * 60      // 20 min

    // MARK: - Staleness & Refresh
    /// Time after which a query result shows as stale in the UI
    static let queryStaleThreshold: TimeInterval = 60             // 1 min
    /// Time after which returning to the app auto-refreshes queries
    static let queryAutoRefreshThreshold: TimeInterval = 15 * 60  // 15 min
    /// Cooldown before retrying after a service loading error
    static let errorRetryCooldown: TimeInterval = 60              // 1 min

    // MARK: - Widget
    /// How often the widget timeline requests a refresh from the system
    static let widgetRefreshInterval: TimeInterval = 2 * 60 * 60  // 2 hours
}

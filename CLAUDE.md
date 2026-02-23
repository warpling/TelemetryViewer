# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TelemetryDeck Viewer is a native macOS and iOS SwiftUI app for viewing analytics from [TelemetryDeck](https://telemetrydeck.com). It is an open-source community project that typically lags behind the official TelemetryDeck web dashboard.

## Build Commands

```bash
# Build macOS
xcodebuild build -project "Telemetry Viewer.xcodeproj" -scheme "Telemetry Viewer (macOS)"

# Build iOS (simulator)
xcodebuild build -project "Telemetry Viewer.xcodeproj" -scheme "Telemetry Viewer (iOS)" -destination "platform=iOS Simulator,name=iPhone 16"

# Build macOS pointing at local API (http://localhost:8080)
xcodebuild build -project "Telemetry Viewer.xcodeproj" -scheme "Telemetry Viewer (macOS, local)"

# Lint
swiftlint

# iOS TestFlight beta (requires signing)
bundle exec fastlane ios beta
```

There are no unit tests. The only test target is a macOS UI test (`Telemetry Viewer Mac UITests`).

## Development Setup

Before building, update `Common.xcconfig` to set `DEVELOPER_BUNDLE_ID` to your own reverse-domain identifier, and set the signing team on each target. **Do not commit these changes.**

## Architecture

### Service Layer Pattern

The app uses `@EnvironmentObject` injection of `ObservableObject` services. All services are instantiated in the platform-specific `@main` App struct and passed down through the SwiftUI environment.

**Service dependency graph** (initialized in `macOS/Telemetry_ViewerApp_macOS.swift` and `iOS/Telemetry_ViewerApp_iOS.swift`):

```
APIClient (HTTP networking, auth, token storage)
├── OrgService(api, errors)      — organization management
├── AppService(api, errors, org) — app data
├── GroupService(api, errors)    — insight groups
├── InsightService(api, errors)  — insight data & calculations
├── QueryService(api, errors)    — time window & filtering
├── SignalsService(api)          — signal data
├── LexiconService(api)         — terminology
├── IconFinderService(api)       — app icons
├── ErrorService                 — centralized error collection
├── UpdateService                — app update checks (macOS)
└── CacheLayer                   — multi-level NSCache wrapper
```

### View Hierarchy

`RootView` is the main entry point. It shows `WelcomeView` (login) when unauthenticated, or `LeftSidebarView` + content when logged in. The login state is driven by `APIClient.userNotLoggedIn`.

### Platform-Specific Code

- `Shared/` — Cross-platform views, helpers, extensions (the bulk of the code)
- `macOS/` — macOS-specific views and app entry point
- `iOS/` — iOS-specific views and app entry point
- Within shared files, `#if os(macOS)` / `#if os(iOS)` is used for platform branching

### API Client

`APIClient.swift` handles all networking. Key details:
- Supports API v1, v2, v3 endpoints
- Base URL switches between local (`http://localhost:8080/api/`) and production (`https://api.telemetrydeck.com/api/`) via the `API_URL` environment variable
- User token is stored in shared `UserDefaults` via App Groups (shared with widget extensions)
- Deep link login: `telemetryviewer://login/<bearertoken>`

### Charting

Two charting systems coexist:
- `SwiftUICharts/` — Standalone chart views (Line, Bar, Donut) with `ChartDataPoint`/`ChartDataSet` models
- `Cluster/` — Newer query-based charting with `ClusterInstrument`, `QueryRunner`, and specialized chart views (`ClusterLineChart`, `ClusterBarChart`, `ClusterPieChart`)

### Widget & Shortcuts Extensions

- `TelemetryDeckWidget/` — iOS widget extension
- `TelemetryDeckMacWidgetExtension/` — macOS widget extension (separate target)
- `TelemetryDeckIntents/` and `TelemetryDeckMacIntents/` — Siri Shortcuts for iOS/macOS

## Dependencies (SPM)

- **DataTransferObjects** (`TelemetryDeck/models`) — Shared DTOs with namespaces `DTOv1`, `DTOv2`, `DTOv3`
- **TelemetryClient** (`AppTelemetry/SwiftClient`) — Telemetry tracking SDK
- **swift-crypto** — Cryptographic utilities
- **DateOperations** — Date manipulation
- **SwiftUI-Shimmer** — Loading shimmer animations

## Code Style

SwiftLint is configured (`.swiftlint.yml`). Key rules:
- `force_cast` and `force_try` are **errors** (not warnings)
- Line length: warning at 200, error at 300
- Type name minimum length: 4 characters
- `identifier_name` rule is disabled globally
- `MockData.swift` is excluded from linting

## Conventions

- Views: `[Feature]View` (e.g., `GroupView`, `InsightGroupsView`)
- Services: `[Domain]Service` (e.g., `OrgService`, `AppService`)
- Local DTOs: `[Domain]Info` wrappers in `APIClient/DTOs/`
- Async patterns: mix of `async/await` and Combine `@Published` properties
- Loading states: `LoadingState` enum (idle, loading, finished, error)
- Main thread updates use `DispatchQueue.main.async` in services

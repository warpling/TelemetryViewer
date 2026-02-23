//
//  AppService.swift
//  AppService
//
//  Created by Daniel Jilg on 17.08.21.
//

import Combine
import DataTransferObjects
import Foundation

class AppService: ObservableObject {
    private let api: APIClient
    private let errorService: ErrorService
    private let orgService: OrgService

    private let loadingState = Cache<DTOv2.App.ID, LoadingState>()

    var loadingCancellable: AnyCancellable?

    @Published var appDictionary: [AppInfo.ID: AppInfo] = [:]
    @Published var loadingStateDictionary: [AppInfo.ID: LoadingState] = [:]

    private static let diskCacheKey = "cachedApps"

    init(api: APIClient, errors: ErrorService, orgService: OrgService) {
        self.api = api
        errorService = errors
        self.orgService = orgService

        loadingCancellable = loadingState.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] in self?.objectWillChange.send() }

        // Restore cached apps from disk so the sidebar isn't empty on launch
        if let cached = DiskCache.load([AppInfo.ID: AppInfo].self, forKey: Self.diskCacheKey) {
            self.appDictionary = cached
        }
    }

    func saveAppsToDisk() {
        DiskCache.save(appDictionary, forKey: Self.diskCacheKey)
    }

    func clearCache() {
        DiskCache.remove(forKey: Self.diskCacheKey)
    }

    func loadingState(for appID: DTOv2.App.ID) -> LoadingState {
        let loadingState = loadingState[appID] ?? .idle

        // after 60 seconds, clear the error, allowing another load
        switch loadingState {
        case let .error(_, date):
            if date < Date() - Timing.errorRetryCooldown {
                self.loadingState[appID] = .idle
                return .idle
            }
        default:
            break
        }

        return loadingState
    }

    func app(withID appID: AppInfo.ID) -> AppInfo? {
        return appDictionary[appID]
    }

    func allApps() async throws -> [AppInfo] {
        let url = api.urlForPath(apiVersion: .v3, "apps")
        return try await api.get(url: url)
    }

    func retrieveApp(with appID: DTOv2.App.ID, callback: ((Result<DTOv2.App, TransferError>) -> Void)? = nil) {
        let url = api.urlForPath(apiVersion: .v3, "apps", appID.uuidString)
        api.get(url) { (result: Result<DTOv2.App, TransferError>) in
            callback?(result)
        }
    }

    func retrieveApp(withID appID: DTOv2.App.ID) async throws -> AppInfo {
//        guard loadingStateDictionary[appID] != .loading else { let error: TransferError = .transferFailed; throw error }
//        loadingStateDictionary[appID] = .loading
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AppInfo, Error>) in
            let url = api.urlForPath(apiVersion: .v3, "apps", appID.uuidString)
            api.get(url) { (result: Result<AppInfo, TransferError>) in
                switch result {
                case let .success(app):

                    continuation.resume(returning: app)

                case let .failure(error):
                    self.errorService.handle(transferError: error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

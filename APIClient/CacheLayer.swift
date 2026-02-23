//
//  CacheLayer.swift
//  CacheLayer
//
//  Created by Daniel Jilg on 17.08.21.
//

import DataTransferObjects
import Foundation

struct InsightResultWrap {
    let chartDataSet: ChartDataSet
    let calculationResult: DTOv2.InsightCalculationResult
}

class CacheLayer: ObservableObject {
    let queue: DispatchQueue = .init(label: "CacheLayer")

    let organizationCache = Cache<String, DTOv2.Organization>(entryLifetime: Timing.organizationCacheTTL)
    let appCache = Cache<DTOv2.App.ID, DTOv2.App>(entryLifetime: Timing.appCacheTTL)
    let groupCache = Cache<DTOv2.Group.ID, DTOv2.Group>(entryLifetime: Timing.groupCacheTTL)
    let insightCache = Cache<DTOv2.Insight.ID, DTOv2.Insight>(entryLifetime: Timing.insightCacheTTL)
    let insightCalculationResultCache = Cache<String, InsightResultWrap>(entryLifetime: Timing.insightResultCacheTTL)
}

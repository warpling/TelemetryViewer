//
//  InsightGroupInfo.swift
//  Telemetry Viewer (iOS)
//
//  Created by Lukas on 21.05.24.
//

import Foundation

public struct InsightGroupInfo: Codable, Hashable, Identifiable {
    public init(id: UUID, title: String, order: Double? = nil, appID: UUID, insights: [InsightInfo]? = nil) {
        self.id = id
        self.title = title
        self.order = order
        self.appID = appID
        self.insights = insights
    }

    public var id: UUID
    public var title: String
    public var order: Double?
    public var appID: UUID
    public var insights: [InsightInfo]?

    public var insightIDs: [UUID] {
        (insights ?? []).map { insight in
            insight.id
        }
    }

    // Custom decoder that skips individual insights that fail to decode
    // (e.g. due to new query types the local DTOs don't support yet),
    // so the group title and metadata are still available.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        order = try container.decodeIfPresent(Double.self, forKey: .order)
        appID = try container.decode(UUID.self, forKey: .appID)

        if var insightsContainer = try? container.nestedUnkeyedContainer(forKey: .insights) {
            var decoded = [InsightInfo]()
            while !insightsContainer.isAtEnd {
                // Use a single-value container so the cursor always advances,
                // even when the element fails to decode.
                let elementContainer = try insightsContainer.superDecoder()
                if let insight = try? InsightInfo(from: elementContainer) {
                    decoded.append(insight)
                }
            }
            insights = decoded.isEmpty ? nil : decoded
        } else {
            insights = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, order, appID, insights
    }
}

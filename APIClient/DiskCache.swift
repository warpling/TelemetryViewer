//
//  DiskCache.swift
//  Telemetry Viewer
//

import DataTransferObjects
import Foundation

/// Simple JSON file-based cache for persisting Codable values across app launches.
enum DiskCache {
    private static let cacheDirectory: URL = {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TelemetryDeckCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static let encoder: JSONEncoder = .telemetryEncoder
    private static let decoder: JSONDecoder = .telemetryDecoder

    static func save<T: Encodable>(_ value: T, forKey key: String) {
        let url = fileURL(for: key)
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("[DiskCache] Save failed for \(key): \(error)")
            #endif
        }
    }

    static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    static func remove(forKey key: String) {
        let url = fileURL(for: key)
        try? FileManager.default.removeItem(at: url)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private static func fileURL(for key: String) -> URL {
        let safeKey = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return cacheDirectory.appendingPathComponent(safeKey + ".json")
    }
}

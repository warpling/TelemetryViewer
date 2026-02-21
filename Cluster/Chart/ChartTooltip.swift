//
//  ChartTooltip.swift
//  Telemetry Viewer
//

import SwiftUI
import Charts

@available(macOS 14.0, iOS 17.0, *)
struct ChartTooltip: View {
    struct Entry: Identifiable {
        let id = UUID()
        let color: Color
        let label: String
        let value: Double
    }

    let entries: [Entry]
    let dateLabel: String

    private let maxEntries = 5
    private let maxLabelLength = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)

            let sorted = entries.sorted { $0.value > $1.value }
            ForEach(Array(sorted.prefix(maxEntries))) { entry in
                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.color)
                        .frame(width: 6, height: 6)
                    Text(truncated(entry.label))
                        .font(.caption2)
                        .lineLimit(1)
                    Spacer()
                    Text(formatted(entry.value))
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }

            if entries.count > maxEntries {
                Text("+\(entries.count - maxEntries) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .frame(width: 160)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func truncated(_ text: String) -> String {
        text.count > maxLabelLength ? String(text.prefix(maxLabelLength)) + "…" : text
    }

    private func formatted(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 10_000 { return String(format: "%.1fK", value / 1_000) }
        if value == value.rounded() { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

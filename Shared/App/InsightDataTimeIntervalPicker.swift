//
//  SwiftUIView.swift
//  Telemetry Viewer (macOS)
//
//  Created by Daniel Jilg on 18.05.21.
//

import SwiftUI

struct InsightDataTimeIntervalPicker: View {
    @EnvironmentObject var queryService: QueryService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            HStack {
                presetButton("7 Days") {
                    queryService.timeWindowEnd = .end(of: .current(.day))
                    queryService.timeWindowBeginning = .goBack(days: 7)
                }
                presetButton("30 Days") {
                    queryService.timeWindowEnd = .end(of: .current(.day))
                    queryService.timeWindowBeginning = .goBack(days: 30)
                }
                presetButton("90 Days") {
                    queryService.timeWindowEnd = .end(of: .current(.day))
                    queryService.timeWindowBeginning = .goBack(days: 90)
                }
                presetButton("365 Days") {
                    queryService.timeWindowEnd = .end(of: .current(.day))
                    queryService.timeWindowBeginning = .goBack(days: 365)
                }
            }

            Divider()

            HStack {
                presetButton("Last Week") {
                    queryService.timeWindowEnd = .end(of: .previous(.weekOfYear))
                    queryService.timeWindowBeginning = .beginning(of: .previous(.weekOfYear))
                }
                presetButton("This Week") {
                    queryService.timeWindowEnd = .end(of: .current(.weekOfYear))
                    queryService.timeWindowBeginning = .beginning(of: .current(.weekOfYear))
                }
            }
            HStack {
                presetButton("Last Month") {
                    queryService.timeWindowEnd = .end(of: .previous(.month))
                    queryService.timeWindowBeginning = .beginning(of: .previous(.month))
                }
                presetButton("This Month") {
                    queryService.timeWindowEnd = .end(of: .current(.month))
                    queryService.timeWindowBeginning = .beginning(of: .current(.month))
                }
                presetButton("2 Months") {
                    queryService.timeWindowEnd = .end(of: .current(.month))
                    queryService.timeWindowBeginning = .beginning(of: .previous(.month))
                }
            }

            HStack {
                presetButton("Last Year") {
                    queryService.timeWindowEnd = .end(of: .previous(.year))
                    queryService.timeWindowBeginning = .beginning(of: .previous(.year))
                }
                presetButton("This Year") {
                    queryService.timeWindowEnd = .end(of: .current(.year))
                    queryService.timeWindowBeginning = .beginning(of: .current(.year))
                }
            }

            let pickerTimeWindowBeginningBinding = Binding(
                get: { self.queryService.timeWindowBeginningDate },
                set: { self.queryService.timeWindowBeginning = .absolute(date: $0) }
            )

            let pickerTimeWindowEndBinding = Binding(
                get: { self.queryService.timeWindowEndDate },
                set: { self.queryService.timeWindowEnd = .absolute(date: $0) }
            )

            Divider()
                .padding(.top, 4)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .center, spacing: 2) {
                    Text("From").font(.caption).foregroundStyle(.secondary)
                    DatePicker("", selection: pickerTimeWindowBeginningBinding, in: ...queryService.timeWindowEndDate, displayedComponents: .date)
                        .labelsHidden()
                }
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 22)
                VStack(alignment: .center, spacing: 2) {
                    Text("Until").font(.caption).foregroundStyle(.secondary)
                    DatePicker("", selection: pickerTimeWindowEndBinding, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func presetButton(_ label: String, action: @escaping () -> Void) -> some View {
        let combined = {
            action()
            dismiss()
        }
        if queryService.activePresetLabel == label {
            Button(label, action: combined).buttonStyle(SmallPrimaryButtonStyle())
        } else {
            Button(label, action: combined).buttonStyle(SmallSecondaryButtonStyle())
        }
    }
}

//
//  SwiftUIView.swift
//  Telemetry Viewer (macOS)
//
//  Created by Daniel Jilg on 18.05.21.
//

import SwiftUI
import TelemetryClient

struct DateRangeMenu: View {
    @EnvironmentObject var queryService: QueryService
    @Binding var showDatePicker: Bool

    var body: some View {
        Menu {
            Section("Quick Ranges") {
                presetItem("7 Days") {
                    queryService.timeWindowEnd = .end(of: .current(.day))
                    queryService.timeWindowBeginning = .goBack(days: 7)
                }
                presetItem("30 Days") {
                    queryService.timeWindowEnd = .end(of: .current(.day))
                    queryService.timeWindowBeginning = .goBack(days: 30)
                }
                presetItem("90 Days") {
                    queryService.timeWindowEnd = .end(of: .current(.day))
                    queryService.timeWindowBeginning = .goBack(days: 90)
                }
                presetItem("365 Days") {
                    queryService.timeWindowEnd = .end(of: .current(.day))
                    queryService.timeWindowBeginning = .goBack(days: 365)
                }
            }

            Section("Relative") {
                presetItem("This Week") {
                    queryService.timeWindowEnd = .end(of: .current(.weekOfYear))
                    queryService.timeWindowBeginning = .beginning(of: .current(.weekOfYear))
                }
                presetItem("Last Week") {
                    queryService.timeWindowEnd = .end(of: .previous(.weekOfYear))
                    queryService.timeWindowBeginning = .beginning(of: .previous(.weekOfYear))
                }
                presetItem("This Month") {
                    queryService.timeWindowEnd = .end(of: .current(.month))
                    queryService.timeWindowBeginning = .beginning(of: .current(.month))
                }
                presetItem("Last Month") {
                    queryService.timeWindowEnd = .end(of: .previous(.month))
                    queryService.timeWindowBeginning = .beginning(of: .previous(.month))
                }
                presetItem("2 Months") {
                    queryService.timeWindowEnd = .end(of: .current(.month))
                    queryService.timeWindowBeginning = .beginning(of: .previous(.month))
                }
                presetItem("This Year") {
                    queryService.timeWindowEnd = .end(of: .current(.year))
                    queryService.timeWindowBeginning = .beginning(of: .current(.year))
                }
                presetItem("Last Year") {
                    queryService.timeWindowEnd = .end(of: .previous(.year))
                    queryService.timeWindowBeginning = .beginning(of: .previous(.year))
                }
            }

            Divider()

            Button {
                TelemetryManager.send("showDatePicker")
                showDatePicker = true
            } label: {
                if queryService.activePresetLabel == nil {
                    Label("Custom Range...", systemImage: "checkmark")
                } else {
                    Text("Custom Range...")
                }
            }
        } label: {
            Text(queryService.toolbarLabel)
                .contentTransition(.numericText())
                .animation(.default, value: queryService.toolbarLabel)
        }
    }

    private func presetItem(_ label: String, action: @escaping () -> Void) -> some View {
        Toggle(isOn: Binding(
            get: { queryService.activePresetLabel == label },
            set: { if $0 { action() } }
        )) {
            Text(label)
        }
    }
}

struct CustomDateRangePicker: View {
    @EnvironmentObject var queryService: QueryService
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("START DATE")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $startDate, in: ...endDate, displayedComponents: .date)
                        #if os(macOS)
                        .datePickerStyle(.field)
                        #endif
                        .labelsHidden()
                        .fixedSize()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                #if os(macOS)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                #else
                                .fill(Color(.secondarySystemBackground))
                                #endif
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("END DATE")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $endDate, in: ...Date(), displayedComponents: .date)
                        #if os(macOS)
                        .datePickerStyle(.field)
                        #endif
                        .labelsHidden()
                        .fixedSize()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                #if os(macOS)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                #else
                                .fill(Color(.secondarySystemBackground))
                                #endif
                        )
                }
            }

            #if os(macOS)
            HStack(spacing: 12) {
                Spacer()

                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Apply") {
                    queryService.timeWindowBeginning = .absolute(date: startDate)
                    queryService.timeWindowEnd = .absolute(date: endDate)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            #else
            HStack(spacing: 12) {
                Button(role: .cancel) {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    queryService.timeWindowBeginning = .absolute(date: startDate)
                    queryService.timeWindowEnd = .absolute(date: endDate)
                    dismiss()
                } label: {
                    Text("Apply")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            #endif
        }
        .padding()
        #if os(macOS)
        .fixedSize()
        #endif
        .onAppear {
            startDate = queryService.timeWindowBeginningDate
            endDate = queryService.timeWindowEndDate
        }
    }
}

//
//  WidgetDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 30/03/26.
//

import SwiftUI

// MARK: - Generic Detail Shell
struct DetailSheetContainer<Content: View>: View {
    let title: String
    let period: String
    @Environment(\.dismiss) private var dismiss
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .navigationTitle("\(title) — \(period)")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { dismiss() }
                            .tint(Color.liteAccent)
                    }
                }
        }
    }
}

// MARK: - Progress Summary Card
struct ProgressSummaryCard: View {
    let valueLabel: String       // e.g. "87.3" oppure "1400"
    let limitLabel: String       // e.g. "/ 120 kWh" oppure "/ 1600 pz"
    let progress: Double
    let progressTint: Color
    let captionText: String
    let trailingView: AnyView?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(valueLabel)
                    .font(.system(.largeTitle, design: .rounded).bold())
                Text(limitLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(progress, 1.0))
                .tint(progressTint)
                .scaleEffect(x: 1, y: 2, anchor: .center)
            if let trailing = trailingView {
                HStack {
                    Text(captionText)
                        .font(.subheadline.bold())
                        .foregroundStyle(progressTint)
                    Spacer()
                    trailing
                }
            } else {
                Text(captionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Hourly Bar Chart Card
struct HourlyBarChartCard: View {
    let title: String
    let data: [(String, Double)]   // (label, value)
    let maxValue: Double?          // nil = auto

    private var effectiveMax: Double {
        maxValue ?? (data.map(\.1).max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.bold())
                .padding(.horizontal)

            ForEach(data, id: \.0) { hour, value in
                HStack(spacing: 10) {
                    Text(hour)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .leading)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.liteAccent.opacity(0.6))
                            .frame(width: geo.size.width * (value / effectiveMax))
                    }
                    .frame(height: 18)
                    Text(String(format: value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", value))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Worker Detail Sheet (invariata)
struct WorkerDetailView: View {
    let shifts: [WorkerShift]
    let period: String

    var body: some View {
        DetailSheetContainer(title: String(localized: "Workers"), period: period) {
            List(shifts) { shift in
                HStack(spacing: 14) {
                    Circle()
                        .fill((shift.present ? Color.green : .red).opacity(0.12))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.subheadline)
                                .foregroundStyle(shift.present ? .green : .red)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shift.name).font(.subheadline.bold())
                        Text(shift.role).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(shift.present ? String(localized: "Present") : String(localized: "Absent"))
                            .font(.caption.bold())
                            .foregroundStyle(shift.present ? .green : .red)
                        Text(String(format: "%.1f h", shift.hours))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Order Detail Sheet (invariata)
struct OrderDetailView: View {
    let orders: [FactoryOrder]
    let period: String

    var body: some View {
        DetailSheetContainer(title: String(localized: "Orders"), period: period) {
            List(orders) { order in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(order.code).font(.subheadline.bold())
                        Spacer()
                        Text(order.status.localized)
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(order.status.color.opacity(0.12), in: Capsule())
                            .foregroundStyle(order.status.color)
                    }
                    Text(order.client).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Label("\(order.quantity) pcs", systemImage: "shippingbox")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Label(order.dueDate, systemImage: "calendar")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Machine Detail Sheet (invariata)
struct MachineDetailView: View {
    let machines: [MachineItem]
    let period: String

    var body: some View {
        DetailSheetContainer(title: String(localized: "Machines"), period: period) {
            List(machines) { machine in
                HStack(spacing: 14) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(machine.status.color)
                        .font(.title3).frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(machine.name).font(.subheadline.bold())
                        Text(machine.type).font(.caption).foregroundStyle(.secondary)
                        Text("Last maintenance: \(machine.lastMaintenance)")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(machine.status.localized)
                            .font(.caption.bold())
                            .foregroundStyle(machine.status.color)
                        if machine.status != .fault {
                            Text(String(format: "%.0f%%", machine.efficiency * 100))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Energy Detail Sheet (invariata)
struct EnergyDetailView: View {
    let usage: Double
    let limit: Double
    let period: String

    var progress: Double { usage / limit }

    // ⚠️ FAKE — dati orari demo. Rimuovere in produzione.
    private let hourlyData: [(String, Double)] = [
        ("06:00", 6.2), ("07:00", 9.8),  ("08:00", 11.4), ("09:00", 10.9),
        ("10:00", 11.2), ("11:00", 10.5), ("12:00", 7.3),  ("13:00", 6.8),
        ("14:00", 11.0), ("15:00", 10.8), ("16:00", 9.4),  ("17:00", 5.2)
    ]

    var body: some View {
        DetailSheetContainer(title: String(localized: "Energy"), period: period) {
            ScrollView {
                VStack(spacing: 16) {
                    ProgressSummaryCard(
                        valueLabel: String(format: "%.1f", usage),
                        limitLabel: "/ \(Int(limit)) kWh",
                        progress: progress,
                        progressTint: progress > 0.8 ? .orange : Color.liteAccent,
                        captionText: String(format: String(localized: "%.0f%% of the threshold used"), progress * 100),
                        trailingView: nil
                    )
                    HourlyBarChartCard(
                        title: String(localized: "Hourly consumption (kWh)"),
                        data: hourlyData,
                        maxValue: 12.0
                    )
                }
                .padding()
            }
            .liteBackground()
        }
    }
}


// MARK: - Alert Model (estraibile in futuro)
private struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

struct AlertDetailView: View {
    let count: Int
    let period: String

    // ⚠️ FAKE — avvisi demo cablati. Rimuovere in produzione.
    private let alerts: [AlertItem] = [
        AlertItem(title: String(localized: "PRESS-01 faulty"),
                  subtitle: String(localized: "Machinery stopped for 2 days"),
                  icon: "exclamationmark.triangle.fill", color: .red),
        AlertItem(title: String(localized: "Order ORD-0418 is late"),
                  subtitle: String(localized: "Delivery expired on March 28th"),
                  icon: "clock.badge.exclamationmark.fill", color: .orange),
        AlertItem(title: String(localized: "High energy consumption"),
                  subtitle: String(localized: "Exceeded 80% of the daily threshold"),
                  icon: "bolt.fill", color: .orange),
    ]

    var body: some View {
        DetailSheetContainer(title: String(localized: "Notices"), period: period) {
            List(alerts) { alert in
                HStack(spacing: 14) {
                    Image(systemName: alert.icon)
                        .foregroundStyle(alert.color)
                        .font(.body).frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(alert.title).font(.subheadline.bold())
                        Text(alert.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Production Detail View (invariata)
struct ProductionDetailView: View {
    let current: Int
    let target: Int
    let period: String

    var progress: Double { Double(current) / Double(target) }

    // ⚠️ FAKE — dati orari demo. Rimuovere in produzione.
    private let hourlyData: [(String, Double)] = [
        ("06:00", 82),  ("07:00", 145), ("08:00", 158),
        ("09:00", 162), ("10:00", 170), ("11:00", 155),
        ("12:00", 90),  ("13:00", 88),  ("14:00", 168),
        ("15:00", 160), ("16:00", 142), ("17:00", 80)
    ]

    @ViewBuilder
    private var trailingStatus: some View {
        if current < target {
            Text("\(target - current) remaining pcs")
                .font(.subheadline).foregroundStyle(.secondary)
        } else {
            Label("Target achieved", systemImage: "checkmark.circle.fill")
                .font(.subheadline.bold()).foregroundStyle(.green)
        }
    }

    var body: some View {
        DetailSheetContainer(title: String(localized: "Production"), period: period) {
            ScrollView {
                VStack(spacing: 16) {
                    ProgressSummaryCard(
                        valueLabel: "\(current)",
                        limitLabel: String(localized: "/ \(target) pcs"),
                        progress: progress,
                        progressTint: progress >= 1.0 ? .green : Color.liteAccent,
                        captionText: String(format: String(localized: "%.0f%% of target"), progress * 100),
                        trailingView: AnyView(trailingStatus)
                    )
                    HourlyBarChartCard(
                        title: String(localized: "Hourly production (pcs)"),
                        data: hourlyData,
                        maxValue: nil   // auto
                    )
                }
                .padding()
            }
            .liteBackground()
        }
    }
}

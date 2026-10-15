//
//  WidgetComponents.swift
//  AriaLite
//
//  Created by Giovanni Michele on 30/03/26.
//

import SwiftUI


// MARK: - Widget Card Container
// Stile base condiviso da tutti i widget
private struct WidgetCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            
    }
}

// MARK: - Widget Header Row
// Header uniforme: label uppercase muted a sinistra, chevron opzionale a destra
private struct WidgetHeader: View {
    let label: String
    let icon: String
    var accentColor: Color = Color.liteAccent
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(accentColor)
            Text(label.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
        }
    }
}

// MARK: - Alert Banner (ridisegnato)
struct AlertBannerWidget: View {
    let count: Int
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) active alerts")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("Tap to see details")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Production Widget (ridisegnato)
struct ProductionWidget: View {
    let current: Int
    let target: Int
    let period: String

    var progress: Double { Double(current) / Double(target) }
    var isComplete: Bool { current >= target }

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    WidgetHeader(
                        label: String(localized: "Production"),
                        icon: "chart.bar.fill",
                        showChevron: true
                    )
                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(current)")
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("/ \(target) pcs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: min(progress, 1.0))
                    .tint(isComplete ? .green : Color.liteAccent)
                    .scaleEffect(x: 1, y: 1.4, anchor: .center)

                HStack {
                    Text("\(Int(progress * 100))% of target")
                        .font(.caption.bold())
                        .foregroundStyle(isComplete ? .green : Color.liteAccent)
                    Spacer()
                    if isComplete {
                        Label("Target achieved", systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    } else {
                        Text("\(target - current) remaining pcs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Reusable Square Widget (ridisegnato)
struct SquareWidget: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String
    let progress: Double
    let progressColor: Color
    var showChevron: Bool = false

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(
                    label: title,
                    icon: icon,
                    accentColor: iconColor,
                    showChevron: showChevron
                )

                Text(value)
                    .font(.system(.title2, design: .rounded).bold())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: min(progress, 1.0))
                        .tint(progressColor)
                        .scaleEffect(x: 1, y: 1.3, anchor: .center)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 96)
        }
    }
}

// MARK: - Workers Widget
struct WorkersWidget: View {
    let active: Int
    let total: Int
    var ratio: Double { Double(active) / Double(total) }

    var body: some View {
        SquareWidget(
            icon: "person.3.fill",
            iconColor: Color.liteAccent,
            title: String(localized: "Workers"),
            value: "\(active)/\(total)",
            subtitle: String(localized: "\(Int(ratio * 100))% present"),
            progress: ratio,
            progressColor: Color.liteAccent,
            showChevron: true
        )
    }
}

// MARK: - Machines Widget
struct MachinesWidget: View {
    let active: Int
    let total: Int
    let efficiency: Double
    private var isGood: Bool { efficiency > 0.8 }

    var body: some View {
        SquareWidget(
            icon: "gearshape.2.fill",
            iconColor: isGood ? Color.liteAccent : .orange,
            title: String(localized: "Machinery"),
            value: "\(active)/\(total)",
            subtitle: String(localized: "\(Int(efficiency * 100))% efficiency"),
            progress: efficiency,
            progressColor: isGood ? Color.liteAccent : .orange,
            showChevron: true
        )
    }
}

// MARK: - Orders Widget (ridisegnato)
struct OrdersWidget: View {
    let pending: Int
    let completed: Int

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(
                    label: String(localized: "Orders"),
                    icon: "doc.text.fill",
                    showChevron: true
                )

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(pending)")
                            .font(.system(.title2, design: .rounded).bold())
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text("Waiting")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 0.5, height: 40)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(completed)")
                            .font(.system(.title2, design: .rounded).bold())
                            .foregroundStyle(.green)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text("Completed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.top, 2)
            }
            .frame(minHeight: 96)
        }
    }
}

// MARK: - Quality Widget (ridisegnato)
struct QualityWidget: View {
    let defectRate: Double
    var isGood: Bool { defectRate < 0.05 }

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(
                    label: String(localized: "Quality"),
                    icon: "checkmark.seal.fill",
                    accentColor: isGood ? .green : .red
                )

                Text(String(format: "%.1f%%", defectRate * 100))
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(isGood ? Color.primary : .red)

                Spacer(minLength: 0)

                Text("Defect rate")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Badge stato pill
                HStack(spacing: 4) {
                    Image(systemName: isGood
                          ? "checkmark.circle.fill"
                          : "xmark.circle.fill")
                    .font(.caption2)
                    Text(isGood ? String(localized: "Normal") : String(localized: "Out of threshold"))
                        .font(.caption2.bold())
                }
                .foregroundStyle(isGood ? .green : .red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (isGood ? Color.green : Color.red).opacity(0.1),
                    in: Capsule()
                )
            }
            .frame(minHeight: 96)
        }
    }
}

// MARK: - Energy Widget (ridisegnato)
struct EnergyWidget: View {
    let usage: Double
    let limit: Double
    var progress: Double { usage / limit }
    var isNearLimit: Bool { progress > 0.8 }

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    WidgetHeader(
                        label: String(localized: "Energy"),
                        icon: "bolt.fill",
                        accentColor: isNearLimit ? .orange : Color.liteAccent,
                        showChevron: true
                    )
                    if isNearLimit {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("Close to the limit")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.orange)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", usage))
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .minimumScaleFactor(0.7)
                    Text("/ \(Int(limit)) kWh")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: min(progress, 1.0))
                    .tint(isNearLimit ? .orange : Color.liteAccent)
                    .scaleEffect(x: 1, y: 1.4, anchor: .center)

                Text(String(format: String(localized: "%.0f%% of the threshold used"), progress * 100))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

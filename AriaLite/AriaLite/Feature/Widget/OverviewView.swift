//
//  OverviewView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 30/03/26.
//

import SwiftUI

// MARK: - Overview View
struct OverviewView: View {
    @State private var selectedPeriod: TimePeriod = .today
    @State private var showWorkerDetail  = false
    @State private var showOrderDetail   = false
    @State private var showMachineDetail = false
    @State private var showEnergyDetail  = false
    @State private var showAlertDetail = false
    @State private var showProductionDetail = false

    private var data: FactorySnapshot {
        FactoryDataProvider.snapshot(for: selectedPeriod)
    }

    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // Period Picker
                    Picker("Periodo", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.2), value: selectedPeriod)

                    // Alert Banner
                    if data.alerts > 0 {
                        AlertBannerWidget(count: data.alerts) {
                            showAlertDetail = true
                        }
                        .padding(.horizontal)
                    }

                    // Produzione (wide)
                    Button { showProductionDetail = true } label: {
                        ProductionWidget(
                            current: data.production,
                            target: data.productionTarget,
                            period: selectedPeriod.rawValue
                        )
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)

                    // Grid 2 colonne
                    LazyVGrid(columns: columns, spacing: 12) {
                        // Operai → sheet
                        Button { showWorkerDetail = true } label: {
                            WorkersWidget(active: data.activeWorkers, total: data.totalWorkers)
                        }
                        .buttonStyle(.plain)

                        // Macchinari → sheet
                        Button { showMachineDetail = true } label: {
                            MachinesWidget(
                                active: data.activeMachines,
                                total: data.totalMachines,
                                efficiency: data.machineEfficiency
                            )
                        }
                        .buttonStyle(.plain)

                        // Ordini → sheet
                        Button { showOrderDetail = true } label: {
                            OrdersWidget(pending: data.pendingOrders, completed: data.completedOrders)
                        }
                        .buttonStyle(.plain)

                        // Qualità → statico
                        QualityWidget(defectRate: data.defectRate)
                    }
                    .padding(.horizontal)

                    // Energia (wide) → sheet
                    Button { showEnergyDetail = true } label: {
                        EnergyWidget(usage: data.energyUsage, limit: data.energyLimit)
                            .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Overview")
            .navigationBarTitleDisplayMode(.large)
            
            .animation(.easeInOut(duration: 0.25), value: selectedPeriod)
        }
        // MARK: Detail Sheets
        .sheet(isPresented: $showWorkerDetail) {
            WorkerDetailView(shifts: data.workerShifts, period: selectedPeriod.rawValue)
        }
        .sheet(isPresented: $showOrderDetail) {
            OrderDetailView(orders: data.orderList, period: selectedPeriod.rawValue)
        }
        .sheet(isPresented: $showMachineDetail) {
            MachineDetailView(machines: data.machineList, period: selectedPeriod.rawValue)
        }
        .sheet(isPresented: $showProductionDetail) {
            ProductionDetailView(
                current: data.production,
                target: data.productionTarget,
                period: selectedPeriod.rawValue
            )
        }
        .sheet(isPresented: $showAlertDetail) {
            AlertDetailView(count: data.alerts, period: selectedPeriod.rawValue)
        }
        .sheet(isPresented: $showEnergyDetail) {
            EnergyDetailView(
                usage: data.energyUsage,
                limit: data.energyLimit,
                period: selectedPeriod.rawValue
            )
        }
    }
}

// MARK: - Worker Detail Sheet
struct WorkerDetailView: View {
    let shifts: [WorkerShift]
    let period: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(shifts) { shift in
                HStack(spacing: 14) {
                    Circle()
                        .fill(shift.present ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundStyle(shift.present ? Color.green : Color.red)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shift.name).font(.subheadline.bold())
                        Text(shift.role).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(shift.present ? "Presente" : "Assente")
                            .font(.caption.bold())
                            .foregroundStyle(shift.present ? Color.green : Color.red)
                        Text(String(format: "%.1f h", shift.hours))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Operai — \(period)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Order Detail Sheet
struct OrderDetailView: View {
    let orders: [FactoryOrder]
    let period: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(orders) { order in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(order.code).font(.subheadline.bold())
                        Spacer()
                        Text(order.status.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(order.status.color.opacity(0.15), in: Capsule())
                            .foregroundStyle(order.status.color)
                    }
                    Text(order.client).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Label("\(order.quantity) pz", systemImage: "shippingbox")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Label(order.dueDate, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Ordini — \(period)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Machine Detail Sheet
struct MachineDetailView: View {
    let machines: [MachineItem]
    let period: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(machines) { machine in
                HStack(spacing: 14) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(machine.status.color)
                        .font(.title3)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(machine.name).font(.subheadline.bold())
                        Text(machine.type).font(.caption).foregroundStyle(.secondary)
                        Text("Ultima manutenzione: \(machine.lastMaintenance)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(machine.status.rawValue)
                            .font(.caption.bold())
                            .foregroundStyle(machine.status.color)
                        if machine.status != .fault {
                            Text(String(format: "%.0f%%", machine.efficiency * 100))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Macchinari — \(period)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Energy Detail Sheet
struct EnergyDetailView: View {
    let usage: Double
    let limit: Double
    let period: String
    @Environment(\.dismiss) private var dismiss

    var progress: Double { usage / limit }

    let hourlyData: [(String, Double)] = [
        ("06:00", 6.2), ("07:00", 9.8), ("08:00", 11.4), ("09:00", 10.9),
        ("10:00", 11.2), ("11:00", 10.5), ("12:00", 7.3), ("13:00", 6.8),
        ("14:00", 11.0), ("15:00", 10.8), ("16:00", 9.4), ("17:00", 5.2)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // Riepilogo
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", usage))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                            Text("/ \(Int(limit)) kWh")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        ProgressView(value: progress)
                            .tint(progress > 0.8 ? .orange : .yellow)
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                        Text(String(format: "%.0f%% della soglia utilizzata", progress * 100))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                    // Consumo orario semplificato
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Consumo orario (kWh)")
                            .font(.subheadline.bold())
                            .padding(.horizontal)
                        ForEach(hourlyData, id: \.0) { hour, value in
                            HStack(spacing: 10) {
                                Text(hour)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 48, alignment: .leading)
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.yellow.opacity(0.7))
                                        .frame(width: geo.size.width * (value / 12.0))
                                }
                                .frame(height: 18)
                                Text(String(format: "%.1f", value))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Energia — \(period)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Alert Banner
struct AlertBannerWidget: View {
    let count: Int
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) Avvisi attivi")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("Tocca per vedere i dettagli")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Production Widget (wide)
struct ProductionWidget: View {
    let current: Int
    let target: Int
    let period: String

    var progress: Double { Double(current) / Double(target) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Produzione", systemImage: "chart.bar.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.blue)
                Spacer()
                Text(period)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(current)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("/ \(target) pz")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: min(progress, 1.0))
                .tint(progress >= 1.0 ? Color.green : Color.blue)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)

            HStack {
                Text("\(Int(progress * 100))% del target")
                    .font(.caption.bold())
                    .foregroundStyle(progress >= 1.0 ? Color.green : Color.blue)
                Spacer()
                if current < target {
                    Text("\(target - current) pz rimanenti")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Target raggiunto ✓")
                        .font(.caption.bold())
                        .foregroundStyle(Color.green)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
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
            iconColor: .purple,
            title: "Operai",
            value: "\(active)/\(total)",
            subtitle: "\(Int(ratio * 100))% presenti",
            progress: ratio,
            progressColor: .purple
        )
    }
}

// MARK: - Machines Widget
struct MachinesWidget: View {
    let active: Int
    let total: Int
    let efficiency: Double

    var body: some View {
        SquareWidget(
            icon: "gearshape.2.fill",
            iconColor: .teal,
            title: "Macchinari",
            value: "\(active)/\(total)",
            subtitle: "\(Int(efficiency * 100))% efficienza",
            progress: efficiency,
            progressColor: efficiency > 0.8 ? .teal : .orange
        )
    }
}

// MARK: - Orders Widget
struct OrdersWidget: View {
    let pending: Int
    let completed: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Ordini", systemImage: "doc.text.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.orange)

            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: 0) {
                VStack(spacing: 3) {
                    Text("\(pending)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("In attesa")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 1, height: 36)

                VStack(spacing: 3) {
                    Text("\(completed)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundStyle(Color.green)
                    Text("Completati")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)

            // chevron navigazione
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Quality Widget
struct QualityWidget: View {
    let defectRate: Double
    var isGood: Bool { defectRate < 0.05 }

    private var valueColor: Color {             // ← tipo esplicito Color
        isGood ? Color.primary : Color.red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Qualità", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isGood ? Color.green : Color.red)

            Text(String(format: "%.1f%%", defectRate * 100))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)    // ← nessuna ambiguità di tipo

            Text("tasso difetti")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Image(systemName: isGood ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                Text(isGood ? "Nella norma" : "Fuori soglia")
                    .font(.caption2.bold())
            }
            .foregroundStyle(isGood ? Color.green : Color.red)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Energy Widget (wide)
struct EnergyWidget: View {
    let usage: Double
    let limit: Double
    var progress: Double { usage / limit }
    var isNearLimit: Bool { progress > 0.8 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Energia", systemImage: "bolt.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.yellow)
                Spacer()
                Text(isNearLimit ? "⚠️ Vicino al limite" : "Normale")
                    .font(.caption.bold())
                    .foregroundStyle(isNearLimit ? .orange : .secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", usage))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("/ \(Int(limit)) kWh")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(isNearLimit ? .orange : .yellow)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}


// MARK: - Reusable Square Widget
struct SquareWidget: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String
    let progress: Double
    let progressColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))

            ProgressView(value: progress)
                .tint(progressColor)
                .scaleEffect(x: 1, y: 1.3, anchor: .center)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}


struct AlertDetailView: View {
    let count: Int
    let period: String
    @Environment(\.dismiss) private var dismiss

    let mockAlerts = [
        ("PRESS-01 in guasto", "Macchinario fermo da 2 giorni", "exclamationmark.triangle.fill", Color.red),
        ("Ordine ORD-0418 in ritardo", "Consegna scaduta il 28 Mar", "clock.badge.exclamationmark.fill", Color.orange),
        ("Consumo energia elevato", "Superato l'80% della soglia giornaliera", "bolt.fill", Color.yellow),
    ]

    var body: some View {
        NavigationView {
            List(mockAlerts, id: \.0) { alert in
                HStack(spacing: 14) {
                    Image(systemName: alert.2)
                        .foregroundStyle(alert.3)
                        .font(.title3)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(alert.0)
                            .font(.subheadline.bold())
                        Text(alert.1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Avvisi — \(period)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}

struct ProductionDetailView: View {
    let current: Int
    let target: Int
    let period: String
    @Environment(\.dismiss) private var dismiss

    var progress: Double { Double(current) / Double(target) }

    // Dati orari mock
    let hourlyData: [(String, Int)] = [
        ("06:00", 82), ("07:00", 145), ("08:00", 158),
        ("09:00", 162), ("10:00", 170), ("11:00", 155),
        ("12:00", 90),  ("13:00", 88), ("14:00", 168),
        ("15:00", 160), ("16:00", 142), ("17:00", 80)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // KPI riepilogo
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(current)")
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                            Text("/ \(target) pz")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(value: min(progress, 1.0))
                            .tint(progress >= 1.0 ? Color.green : Color.blue)
                            .scaleEffect(x: 1, y: 2, anchor: .center)

                        HStack {
                            Text(String(format: "%.0f%% del target", progress * 100))
                                .font(.subheadline.bold())
                                .foregroundStyle(progress >= 1.0 ? Color.green : Color.blue)
                            Spacer()
                            if current < target {
                                Text("\(target - current) pz rimanenti")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Target raggiunto ✓")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.green)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 16))

                    // Produzione oraria
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Produzione oraria (pz)")
                            .font(.subheadline.bold())
                            .padding(.horizontal)

                        let maxVal = hourlyData.map(\.1).max() ?? 1

                        ForEach(hourlyData, id: \.0) { hour, value in
                            HStack(spacing: 10) {
                                Text(hour)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 48, alignment: .leading)

                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.blue.opacity(0.75))
                                        .frame(width: geo.size.width * (Double(value) / Double(maxVal)))
                                }
                                .frame(height: 20)

                                Text("\(value)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Produzione — \(period)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    OverviewView()
}


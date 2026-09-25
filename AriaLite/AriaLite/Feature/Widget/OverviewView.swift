//
//  OverviewView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 30/03/26.
//

import SwiftUI
import SwiftUI
import Charts

// MARK: - Overview View (invariata nella struttura)
struct OverviewView: View {
    @State private var selectedPeriod: TimePeriod = .today
    @State private var showWorkerDetail     = false
    @State private var showOrderDetail      = false
    @State private var showMachineDetail    = false
    @State private var showEnergyDetail     = false
    @State private var showAlertDetail      = false
    @State private var showProductionDetail = false

    private var data: FactorySnapshot {
        FactoryDataProvider.snapshot(for: selectedPeriod)
    }

    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) {
                            Text($0.localized).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.2), value: selectedPeriod)

                    if data.alerts > 0 {
                        AlertBannerWidget(count: data.alerts) {
                            showAlertDetail = true
                        }
                        .padding(.horizontal)
                    }

                    Button { showProductionDetail = true } label: {
                        ProductionWidget(
                            current: data.production,
                            target: data.productionTarget,
                            period: selectedPeriod.localized
                        )
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)

                    LazyVGrid(columns: columns, spacing: 12) {
                        Button { showWorkerDetail = true } label: {
                            WorkersWidget(active: data.activeWorkers, total: data.totalWorkers)
                        }
                        .buttonStyle(.plain)

                        Button { showMachineDetail = true } label: {
                            MachinesWidget(
                                active: data.activeMachines,
                                total: data.totalMachines,
                                efficiency: data.machineEfficiency
                            )
                        }
                        .buttonStyle(.plain)

                        Button { showOrderDetail = true } label: {
                            OrdersWidget(pending: data.pendingOrders, completed: data.completedOrders)
                        }
                        .buttonStyle(.plain)

                        QualityWidget(defectRate: data.defectRate)
                    }
                    .padding(.horizontal)

                    Button { showEnergyDetail = true } label: {
                        EnergyWidget(usage: data.energyUsage, limit: data.energyLimit)
                            .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical)
            }
            .liteBackground()
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
            }
            .animation(.easeInOut(duration: 0.25), value: selectedPeriod)
        }
        .sheet(isPresented: $showWorkerDetail) {
            WorkerDetailView(shifts: data.workerShifts, period: selectedPeriod.localized)
        }
        .sheet(isPresented: $showOrderDetail) {
            OrderDetailView(orders: data.orderList, period: selectedPeriod.localized)
        }
        .sheet(isPresented: $showMachineDetail) {
            MachineDetailView(machines: data.machineList, period: selectedPeriod.localized)
        }
        .sheet(isPresented: $showProductionDetail) {
            ProductionDetailView(
                current: data.production,
                target: data.productionTarget,
                period: selectedPeriod.localized
            )
        }
        .sheet(isPresented: $showAlertDetail) {
            AlertDetailView(count: data.alerts, period: selectedPeriod.localized)
        }
        .sheet(isPresented: $showEnergyDetail) {
            EnergyDetailView(
                usage: data.energyUsage,
                limit: data.energyLimit,
                period: selectedPeriod.localized
            )
        }
    }
}



// MARK: - Preview
#Preview {
    OverviewView()
}

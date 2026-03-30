//
//  Mock data.swift
//  AriaLite
//
//  Created by Giovanni Michele on 30/03/26.
//

import Foundation
import SwiftUI

// MARK: - Period
enum TimePeriod: String, CaseIterable {
    case today    = "Oggi"
    case week     = "Settimana"
    case month    = "Mese"
}

// MARK: - Data Model
struct FactorySnapshot {
    var production: Int
    var productionTarget: Int
    var activeWorkers: Int
    var totalWorkers: Int
    var machineEfficiency: Double
    var activeMachines: Int
    var totalMachines: Int
    var pendingOrders: Int
    var completedOrders: Int
    var defectRate: Double
    var energyUsage: Double
    var energyLimit: Double
    var alerts: Int
    var workerShifts: [WorkerShift]
    var orderList: [FactoryOrder]
    var machineList: [MachineItem]
}

struct WorkerShift: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let hours: Double
    let present: Bool
}

struct FactoryOrder: Identifiable {
    let id = UUID()
    let code: String
    let client: String
    let quantity: Int
    let status: OrderStatus
    let dueDate: String
}

enum OrderStatus: String {
    case pending    = "In attesa"
    case processing = "In lavorazione"
    case completed  = "Completato"
    case delayed    = "In ritardo"

    var color: Color {
        switch self {
        case .pending:    return .orange
        case .processing: return .blue
        case .completed:  return .green
        case .delayed:    return .red
        }
    }
}

struct MachineItem: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let efficiency: Double
    let status: MachineStatus
    let lastMaintenance: String
}

enum MachineStatus: String {
    case running  = "Operativa"
    case idle     = "Ferma"
    case fault    = "Guasto"

    var color: Color {
        switch self {
        case .running: return .green
        case .idle:    return .orange
        case .fault:   return .red
        }
    }
}

// MARK: - Mock Data Provider
struct FactoryDataProvider {
    static func snapshot(for period: TimePeriod) -> FactorySnapshot {
        switch period {
        case .today:
            return FactorySnapshot(
                production: 1_240, productionTarget: 1_500,
                activeWorkers: 48, totalWorkers: 60,
                machineEfficiency: 0.87, activeMachines: 12, totalMachines: 14,
                pendingOrders: 23, completedOrders: 187,
                defectRate: 0.032, energyUsage: 84.5, energyLimit: 100.0,
                alerts: 3,
                workerShifts: [
                    WorkerShift(name: "Mario Rossi",   role: "Operatore CNC",  hours: 8.0, present: true),
                    WorkerShift(name: "Laura Bianchi", role: "Controllo Qual.", hours: 8.0, present: true),
                    WorkerShift(name: "Luca Verdi",    role: "Magazziniere",   hours: 6.5, present: true),
                    WorkerShift(name: "Sara Neri",     role: "Supervisore",    hours: 8.0, present: true),
                    WorkerShift(name: "Giulio Ferri",  role: "Manutentore",    hours: 0.0, present: false),
                ],
                orderList: [
                    FactoryOrder(code: "ORD-0421", client: "Alfa Srl",      quantity: 500,  status: .processing, dueDate: "02 Apr"),
                    FactoryOrder(code: "ORD-0422", client: "Beta SpA",      quantity: 1200, status: .pending,    dueDate: "05 Apr"),
                    FactoryOrder(code: "ORD-0419", client: "Gamma Ltd",     quantity: 300,  status: .completed,  dueDate: "30 Mar"),
                    FactoryOrder(code: "ORD-0418", client: "Delta Corp",    quantity: 800,  status: .delayed,    dueDate: "28 Mar"),
                ],
                machineList: [
                    MachineItem(name: "CNC-01",   type: "Centro di lavoro",  efficiency: 0.94, status: .running, lastMaintenance: "15 Mar"),
                    MachineItem(name: "CNC-02",   type: "Centro di lavoro",  efficiency: 0.88, status: .running, lastMaintenance: "10 Mar"),
                    MachineItem(name: "PRESS-01", type: "Pressa idraulica",  efficiency: 0.0,  status: .fault,   lastMaintenance: "02 Feb"),
                    MachineItem(name: "WELD-01",  type: "Saldatrice robot.",  efficiency: 0.91, status: .running, lastMaintenance: "20 Mar"),
                    MachineItem(name: "LATHE-01", type: "Tornio CNC",        efficiency: 0.0,  status: .idle,    lastMaintenance: "01 Mar"),
                ]
            )
        case .week:
            return FactorySnapshot(
                production: 7_820, productionTarget: 9_000,
                activeWorkers: 55, totalWorkers: 60,
                machineEfficiency: 0.82, activeMachines: 13, totalMachines: 14,
                pendingOrders: 41, completedOrders: 312,
                defectRate: 0.041, energyUsage: 512.0, energyLimit: 700.0,
                alerts: 5,
                workerShifts: [
                    WorkerShift(name: "Mario Rossi",    role: "Operatore CNC",  hours: 40.0, present: true),
                    WorkerShift(name: "Laura Bianchi",  role: "Controllo Qual.", hours: 38.5, present: true),
                    WorkerShift(name: "Luca Verdi",     role: "Magazziniere",   hours: 35.0, present: true),
                    WorkerShift(name: "Sara Neri",      role: "Supervisore",    hours: 40.0, present: true),
                    WorkerShift(name: "Giulio Ferri",   role: "Manutentore",    hours: 16.0, present: false),
                ],
                orderList: [
                    FactoryOrder(code: "ORD-0420", client: "Omega Inc",     quantity: 2000, status: .completed,  dueDate: "29 Mar"),
                    FactoryOrder(code: "ORD-0421", client: "Alfa Srl",      quantity: 500,  status: .processing, dueDate: "02 Apr"),
                    FactoryOrder(code: "ORD-0422", client: "Beta SpA",      quantity: 1200, status: .pending,    dueDate: "05 Apr"),
                    FactoryOrder(code: "ORD-0418", client: "Delta Corp",    quantity: 800,  status: .delayed,    dueDate: "28 Mar"),
                    FactoryOrder(code: "ORD-0423", client: "Epsilon Srl",   quantity: 450,  status: .pending,    dueDate: "08 Apr"),
                ],
                machineList: [
                    MachineItem(name: "CNC-01",   type: "Centro di lavoro", efficiency: 0.91, status: .running, lastMaintenance: "15 Mar"),
                    MachineItem(name: "CNC-02",   type: "Centro di lavoro", efficiency: 0.85, status: .running, lastMaintenance: "10 Mar"),
                    MachineItem(name: "PRESS-01", type: "Pressa idraulica", efficiency: 0.0,  status: .fault,   lastMaintenance: "02 Feb"),
                    MachineItem(name: "WELD-01",  type: "Saldatrice robot.", efficiency: 0.88, status: .running, lastMaintenance: "20 Mar"),
                    MachineItem(name: "LATHE-01", type: "Tornio CNC",       efficiency: 0.72, status: .running, lastMaintenance: "01 Mar"),
                ]
            )
        case .month:
            return FactorySnapshot(
                production: 31_400, productionTarget: 40_000,
                activeWorkers: 58, totalWorkers: 60,
                machineEfficiency: 0.79, activeMachines: 14, totalMachines: 14,
                pendingOrders: 67, completedOrders: 1_204,
                defectRate: 0.027, energyUsage: 2_140.0, energyLimit: 3_000.0,
                alerts: 8,
                workerShifts: [
                    WorkerShift(name: "Mario Rossi",    role: "Operatore CNC",  hours: 168.0, present: true),
                    WorkerShift(name: "Laura Bianchi",  role: "Controllo Qual.", hours: 160.0, present: true),
                    WorkerShift(name: "Luca Verdi",     role: "Magazziniere",   hours: 152.0, present: true),
                    WorkerShift(name: "Sara Neri",      role: "Supervisore",    hours: 168.0, present: true),
                    WorkerShift(name: "Giulio Ferri",   role: "Manutentore",    hours: 80.0,  present: true),
                ],
                orderList: [
                    FactoryOrder(code: "ORD-0410", client: "Zeta Group",    quantity: 5000, status: .completed,  dueDate: "15 Mar"),
                    FactoryOrder(code: "ORD-0415", client: "Omega Inc",     quantity: 2000, status: .completed,  dueDate: "22 Mar"),
                    FactoryOrder(code: "ORD-0421", client: "Alfa Srl",      quantity: 500,  status: .processing, dueDate: "02 Apr"),
                    FactoryOrder(code: "ORD-0422", client: "Beta SpA",      quantity: 1200, status: .pending,    dueDate: "05 Apr"),
                    FactoryOrder(code: "ORD-0423", client: "Epsilon Srl",   quantity: 450,  status: .pending,    dueDate: "08 Apr"),
                    FactoryOrder(code: "ORD-0418", client: "Delta Corp",    quantity: 800,  status: .delayed,    dueDate: "28 Mar"),
                ],
                machineList: [
                    MachineItem(name: "CNC-01",   type: "Centro di lavoro", efficiency: 0.89, status: .running, lastMaintenance: "15 Mar"),
                    MachineItem(name: "CNC-02",   type: "Centro di lavoro", efficiency: 0.84, status: .running, lastMaintenance: "10 Mar"),
                    MachineItem(name: "PRESS-01", type: "Pressa idraulica", efficiency: 0.75, status: .running, lastMaintenance: "25 Mar"),
                    MachineItem(name: "WELD-01",  type: "Saldatrice robot.", efficiency: 0.90, status: .running, lastMaintenance: "20 Mar"),
                    MachineItem(name: "LATHE-01", type: "Tornio CNC",       efficiency: 0.71, status: .running, lastMaintenance: "01 Mar"),
                ]
            )
        }
    }
}

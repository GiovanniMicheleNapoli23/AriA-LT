//
//  AdminWorkOrderDraft.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I campi del form di un ordine, come li modifica l'utente: testi semplici e interruttori per le date
//  facoltative. Il view model li confronta con l'originale e ne fa il body di POST o PATCH.
//

import Foundation

nonisolated struct AdminWorkOrderDraft: Equatable, Sendable {
    var title = ""
    var description = ""
    var type: AdminWorkOrderType = .reactive
    var category = ""
    var priority: AdminWorkOrderPriority = .medium
    var status: AdminWorkOrderStatus = .planned
    var assetTag: String?
    var plantId: String?
    var zone = ""
    var hasScheduledDate = false
    var scheduledDate: Date
    var hasDueDate = false
    var dueDate: Date
    /// Minuti scritti a mano: si controllano al salvataggio.
    var estimatedMinutes = ""
    var assignedUserId: String?
    var teamId: String?
    var notes = ""
    var resolutionNotes = ""

    /// Un ordine nuovo nello stabilimento dato; le date, se si accendono, partono da domani alle 9.
    init(plantId: String?, now: Date = .now) {
        self.plantId = plantId
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now
        let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        scheduledDate = start
        dueDate = start
    }

    /// Lo stato attuale di un ordine esistente.
    init(order: AdminWorkOrder, now: Date = .now) {
        self.init(plantId: order.plantId, now: now)
        title = order.title
        description = order.description ?? ""
        type = order.type.flatMap { $0 == .unknown ? nil : $0 } ?? .reactive
        category = order.category ?? ""
        priority = order.priority.flatMap { $0 == .unknown ? nil : $0 } ?? .medium
        status = order.status.flatMap { $0 == .unknown ? nil : $0 } ?? .planned
        assetTag = order.assetTag
        zone = order.zone ?? ""
        if let date = order.scheduledDate {
            hasScheduledDate = true
            scheduledDate = date
        }
        if let date = order.dueDate {
            hasDueDate = true
            dueDate = date
        }
        estimatedMinutes = order.estimatedDurationMin.map(String.init) ?? ""
        assignedUserId = order.assignedToUserId
        teamId = order.assignedToTeamId
        notes = order.notes ?? ""
        resolutionNotes = order.resolutionNotes ?? ""
    }
}

/// Una voce scelta da un elenco lungo (asset, persone, squadre).
nonisolated struct AdminWorkOrderChoice: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
}

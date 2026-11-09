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
    /// Chi ha chiesto il lavoro (testo libero, `requested_by`).
    var requestedBy = ""
    /// Il codice allarme da cui nasce l'ordine: si scrive solo creando (WorkOrderUpdate non lo accetta).
    var alarmCode = ""
    /// La procedura, solo creando: va in `checklist_data` (vedi AdminWorkOrderChecklist).
    var steps: [AdminWorkOrderDraftStep] = []
    /// Sicurezza, attrezzi e ricambi proposti dall'AI: vanno nella stessa checklist.
    var safetyWarnings: [String] = []
    var toolsNeeded: [String] = []
    var partsNeeded: [String] = []

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
        requestedBy = order.requestedBy ?? ""
        alarmCode = order.alarmCode ?? ""
    }
}

/// Una persona o un operatore sul campo da assegnare. Per gli operatori anche disponibilità e carico.
nonisolated struct AdminWorkOrderFormAssignee: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    /// Solo per gli operatori; `nil` per le persone o se il server manda un valore sconosciuto.
    let availability: AriaAvailability?
    /// "3 open · 2 h" per gli operatori.
    let workload: String?

    /// Le voci che contengono il testo cercato, nel nome o nel sottotitolo.
    static func matching(_ query: String, in items: [Self]) -> [Self] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.title.localizedStandardContains(query) || $0.subtitle?.localizedStandardContains(query) == true
        }
    }
}

/// Una voce scelta da un elenco lungo (asset, persone, squadre).
nonisolated struct AdminWorkOrderChoice: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
}

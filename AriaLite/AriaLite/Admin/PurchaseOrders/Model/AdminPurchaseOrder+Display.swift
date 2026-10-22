//
//  AdminPurchaseOrder+Display.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Quello che la lista deduce da un ordine: il totale da mostrare e se la consegna è in ritardo.
//

import Foundation

extension AdminPurchaseOrder {
    /// Il totale del server; se manca, la somma dei totali di riga (solo righe con quantità e costo).
    /// `nil` se non si può calcolare.
    nonisolated var displayTotal: Double? {
        if let totalCost { return totalCost }
        let totals = lines.compactMap(\.lineTotal)
        return totals.isEmpty ? nil : totals.reduce(0, +)
    }

    /// Consegna prevista già passata (a giorni, nel fuso del telefono) e ordine ancora aperto:
    /// non ricevuto, annullato né rifiutato.
    nonisolated func isOverdue(now: Date = .now) -> Bool {
        switch statusKind {
        case .received, .cancelled, .rejected: return false
        default: break
        }
        guard let dueDay = AdminPurchaseOrderDayText.string(fromRaw: expectedDelivery) else { return false }
        return dueDay < AdminPurchaseOrderDayText.string(fromLocal: now)
    }

    /// Da approvare: in attesa di approvazione.
    nonisolated var isAwaitingApproval: Bool { statusKind == .pendingApproval }

    /// Da ricevere: approvato, ordinato o ricevuto in parte.
    nonisolated var isToReceive: Bool { statusKind.canReceive }
}

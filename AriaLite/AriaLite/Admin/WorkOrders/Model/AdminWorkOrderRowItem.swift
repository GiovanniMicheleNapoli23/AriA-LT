//
//  AdminWorkOrderRowItem.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga della lista già pronta da mostrare: testi e stato calcolati dal view model.
//

import Foundation

nonisolated struct AdminWorkOrderRowItem: Identifiable, Hashable, Sendable {
    let order: AdminWorkOrder
    let status: AdminWorkOrderStatus?
    let priority: AdminWorkOrderPriority?
    /// "TAG · Zona".
    let place: String
    let assignee: String?
    let due: String?
    let isOverdue: Bool
    /// `nil` senza procedura.
    let progress: Double?
    /// "3/5".
    let progressText: String?
    /// Un cambio di stato in volo.
    var isBusy = false

    var id: String { order.id }
}

/// La voce di navigazione verso il dettaglio: porta l'ordine della lista, mostrato subito mentre si aggiorna.
nonisolated struct AdminWorkOrderRoute: Hashable, Sendable {
    let order: AdminWorkOrder
}

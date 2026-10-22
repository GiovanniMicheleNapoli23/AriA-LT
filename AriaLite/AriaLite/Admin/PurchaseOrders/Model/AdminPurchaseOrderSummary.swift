//
//  AdminPurchaseOrderSummary.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il riepilogo sopra la lista: quanti ordini, quanti da approvare, da ricevere, in ritardo e il valore totale.
//

import SwiftUI

nonisolated struct AdminPurchaseOrderSummary: Equatable, Sendable {
    let count: Int
    let awaitingApproval: Int
    let toReceive: Int
    let overdue: Int
    /// La somma dei totali che si conoscono.
    let totalValue: Double

    init(orders: [AdminPurchaseOrder], now: Date = .now) {
        count = orders.count
        awaitingApproval = orders.count(where: \.isAwaitingApproval)
        toReceive = orders.count(where: \.isToReceive)
        overdue = orders.count { $0.isOverdue(now: now) }
        totalValue = orders.compactMap(\.displayTotal).reduce(0, +)
    }
}

/// Una casella del riepilogo.
nonisolated struct AdminPurchaseOrderSummaryTile: Identifiable, Sendable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
}

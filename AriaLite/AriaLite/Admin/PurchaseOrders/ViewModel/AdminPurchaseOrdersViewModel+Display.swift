//
//  AdminPurchaseOrdersViewModel+Display.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Quello che la lista mostra: ricerca, schede, riepilogo, titoli dei filtri e segnaposto.
//  Tutte le decisioni di presentazione stanno qui: le viste disegnano e basta.
//

import SwiftUI

extension AdminPurchaseOrdersViewModel {
    // MARK: - Ricerca

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Gli ordini che passano la ricerca (titolo, fornitore, note); stato e fornitore li filtra il server.
    var visibleOrders: [AdminPurchaseOrder] {
        let q = trimmedQuery
        guard !q.isEmpty else { return orders }
        return orders.filter { order in
            [order.title, lookups.vendorName(for: order.vendorId), order.notes].contains {
                $0?.localizedStandardContains(q) == true
            }
        }
    }

    /// Le schede della lista.
    var rows: [AdminPurchaseOrderRowInfo] {
        let now = Date.now
        return visibleOrders.map {
            AdminPurchaseOrderRowInfo(order: $0, vendorName: lookups.vendorName(for: $0.vendorId), now: now)
        }
    }

    // MARK: - Riepilogo

    /// Le caselle del riepilogo, sugli ordini visibili; "in ritardo" compare solo se ce ne sono.
    var summaryTiles: [AdminPurchaseOrderSummaryTile] {
        let summary = AdminPurchaseOrderSummary(orders: visibleOrders)
        var tiles = [
            AdminPurchaseOrderSummaryTile(id: "count", title: String(localized: "Orders"),
                                          value: summary.count.formatted(), systemImage: "cart", tint: Color.liteAccent),
            AdminPurchaseOrderSummaryTile(id: "approval", title: String(localized: "Awaiting approval"),
                                          value: summary.awaitingApproval.formatted(), systemImage: "clock", tint: .orange),
            AdminPurchaseOrderSummaryTile(id: "receive", title: String(localized: "To receive"),
                                          value: summary.toReceive.formatted(), systemImage: "shippingbox", tint: .blue)
        ]
        if summary.overdue > 0 {
            tiles.append(AdminPurchaseOrderSummaryTile(id: "overdue", title: String(localized: "Overdue"),
                                                       value: summary.overdue.formatted(),
                                                       systemImage: "exclamationmark.triangle", tint: .red))
        }
        tiles.append(AdminPurchaseOrderSummaryTile(id: "value", title: String(localized: "Total value"),
                                                   value: AdminPurchaseOrderMoney.format(summary.totalValue),
                                                   systemImage: "banknote", tint: .green))
        return tiles
    }

    // MARK: - Filtri

    /// Tutti gli stati noti: il filtro lo applica il server, non si deduce dall'elenco.
    var statusOptions: [AdminPurchaseOrderStatus] { AdminPurchaseOrderStatus.filterCases }

    var vendorOptions: [AdminSparePartVendor] { lookups.sortedVendors }

    var statusFilterTitle: String { statusFilter?.label ?? String(localized: "Status") }

    var vendorFilterTitle: String {
        guard let vendorFilter else { return String(localized: "Vendor") }
        return lookups.vendorName(for: vendorFilter) ?? String(localized: "Vendor")
    }

    // MARK: - Segnaposto

    var placeholder: Placeholder? {
        if !hasLoaded {
            if let failure = currentFailure { return .failed(failure) }
            return .loading
        }
        if orders.isEmpty {
            if backend.activePlantId == nil { return .noPlant }
            return hasActiveFilters ? .noMatches : .empty
        }
        guard visibleOrders.isEmpty else { return nil }
        return .noResults(trimmedQuery)
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito.
    var refreshFailed: Bool { hasLoaded && currentFailure != nil }

    /// Perché il "+" è spento.
    var createDisabledReason: String? {
        canCreate ? nil : String(localized: "Choose a plant to create purchase orders.")
    }
}

//
//  AdminPurchaseOrderDetailViewModel+Display.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Ciò che il dettaglio mostra, già scritto: testata (fornitore, totale, ritardo), scheda dei dati e righe
//  con nome del ricambio, quantità, costi e subtotale. Le viste si limitano a metterlo in pagina.
//

import Foundation

/// Una riga della scheda dei dati. I testi lunghi (indirizzo, note) vanno a capo sotto l'etichetta.
struct AdminPurchaseOrderDetailInfoRow: Identifiable, Hashable {
    let label: String
    let value: String
    var isBlock = false
    var id: String { label }
}

/// Una riga dell'ordine pronta da mostrare.
struct AdminPurchaseOrderDetailLine: Identifiable, Hashable {
    let id: String
    /// Il nome del ricambio se si conosce, altrimenti il codice.
    let title: String
    /// Il codice, sotto il nome, quando il titolo è il nome.
    let code: String?
    let quantity: String
    let unitCost: String?
    let total: String?
    let notes: String?
}

extension AdminPurchaseOrderDetailViewModel {
    // MARK: - Testata

    var vendorName: String {
        lookups.vendorName(for: order.vendorId) ?? String(localized: "No vendor")
    }

    /// Il totale del server, altrimenti la somma delle righe; `nil` se non c'è né l'uno né l'altra.
    var totalValue: Double? {
        order.totalCost ?? AdminPurchaseOrderDetailFormat.sum(of: order.lines)
    }

    var totalText: String {
        totalValue.map(AdminPurchaseOrderDetailFormat.money) ?? String(localized: "Not set")
    }

    var expectedDeliveryText: String? {
        AdminPurchaseOrderDetailFormat.day(raw: order.expectedDelivery, value: order.expectedDeliveryValue)
    }

    /// Consegna prevista già passata e ordine ancora aperto (non ricevuto, annullato o rifiutato).
    var isOverdue: Bool {
        switch order.statusKind {
        case .received, .cancelled, .rejected: return false
        default: break
        }
        return AdminPurchaseOrderDetailFormat.isPast(raw: order.expectedDelivery, value: order.expectedDeliveryValue)
    }

    var overdueText: String? {
        guard isOverdue, let date = expectedDeliveryText else { return nil }
        return String(localized: "Overdue: delivery was expected on \(date)")
    }

    // MARK: - Scheda dei dati

    var plantName: String? {
        guard let id = order.plantId else { return nil }
        return backend.plants.first { $0.id == id }?.name
    }

    var infoRows: [AdminPurchaseOrderDetailInfoRow] {
        let fmt = AdminPurchaseOrderDetailFormat.self
        let rows: [(String, String?, Bool)] = [
            (String(localized: "Order date"), fmt.day(raw: order.orderDate, value: order.orderDateValue), false),
            (String(localized: "Expected delivery"), expectedDeliveryText, false),
            (String(localized: "Plant"), plantName, false),
            (String(localized: "Approved by"), approverName, false),
            (String(localized: "Approved on"), fmt.dateTime(order.approvedAtValue), false),
            (String(localized: "Shipping address"), order.shippingAddress, true),
            (String(localized: "Notes"), order.notes, true),
            (String(localized: "Created"), fmt.dateTime(order.createdAtValue), false),
            (String(localized: "Updated"), fmt.dateTime(order.updatedAtValue), false),
        ]
        return rows.compactMap { label, value, isBlock in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
            return AdminPurchaseOrderDetailInfoRow(label: label, value: value, isBlock: isBlock)
        }
    }

    // MARK: - Righe

    var lineDisplays: [AdminPurchaseOrderDetailLine] {
        let fmt = AdminPurchaseOrderDetailFormat.self
        return order.lines.map { line in
            let part = spareParts.part(id: line.partId, code: line.partCode)
            let code = line.partCode ?? part?.code
            let name = part.flatMap { $0.name.isEmpty ? nil : $0.name }
            let quantity = line.quantity.map(fmt.quantity).map { amount in
                part?.unit.map { "\(amount) \($0)" } ?? amount
            }
            let notes = line.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
            return AdminPurchaseOrderDetailLine(
                id: line.id,
                title: name ?? code ?? String(localized: "Unnamed part"),
                code: name == nil ? nil : code,
                quantity: quantity ?? "—",
                unitCost: line.unitCost.map(fmt.money),
                total: line.lineTotal.map(fmt.money),
                notes: notes?.isEmpty == false ? notes : nil)
        }
    }

    var subtotalText: String? {
        AdminPurchaseOrderDetailFormat.sum(of: order.lines).map(AdminPurchaseOrderDetailFormat.money)
    }

    var lineCount: Int { order.lines.count }
}

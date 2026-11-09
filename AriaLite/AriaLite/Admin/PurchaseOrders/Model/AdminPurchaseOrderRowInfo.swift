//
//  AdminPurchaseOrderRowInfo.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Tutto quello che la scheda di un ordine nella lista scrive, già pronto: testi, ritardo, totale.
//  La vista lo disegna e basta.
//

import Foundation

nonisolated struct AdminPurchaseOrderRowInfo: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let vendorName: String?
    let status: AdminPurchaseOrderStatus
    /// "Ordered 12 Oct 2026".
    let orderDateText: String?
    /// "Expected 20 Oct 2026", oppure "Overdue, expected 20 Oct 2026" se la consegna è in ritardo.
    let expectedText: String?
    let isOverdue: Bool
    /// L'importo o "—".
    let totalText: String
    /// "3 lines", "1 line", "No lines".
    let linesText: String

    init(order: AdminPurchaseOrder, vendorName: String?, now: Date = .now) {
        id = order.id
        title = order.title
        self.vendorName = vendorName
        status = order.statusKind
        isOverdue = order.isOverdue(now: now)
        orderDateText = order.orderDateValue.map {
            String(localized: "Ordered \(AdminPurchaseOrderDayText.display($0))")
        }
        expectedText = order.expectedDeliveryValue.map { date in
            let day = AdminPurchaseOrderDayText.display(date)
            return order.isOverdue(now: now)
                ? String(localized: "Overdue, expected \(day)")
                : String(localized: "Expected \(day)")
        }
        totalText = AdminPurchaseOrderMoney.format(order.displayTotal)
        linesText = switch order.lines.count {
        case 0: String(localized: "No lines")
        case 1: String(localized: "1 line")
        case let count: String(localized: "\(count) lines")
        }
    }
}

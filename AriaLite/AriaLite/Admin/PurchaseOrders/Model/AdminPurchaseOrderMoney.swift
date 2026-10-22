//
//  AdminPurchaseOrderMoney.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli importi degli ordini. Il backend non dice la valuta: si usa quella della lingua del telefono,
//  euro se non c'è.
//

import Foundation

nonisolated enum AdminPurchaseOrderMoney {
    /// Il segnaposto quando un importo non c'è.
    static let missing = "—"

    static var currencyCode: String { Locale.current.currency?.identifier ?? "EUR" }

    /// "€ 1.250,00".
    static func format(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode))
    }

    /// L'importo, o il segnaposto se manca.
    static func format(_ value: Double?) -> String {
        value.map { format($0) } ?? missing
    }
}

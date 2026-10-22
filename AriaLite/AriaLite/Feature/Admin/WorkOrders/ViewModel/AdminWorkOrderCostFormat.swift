//
//  AdminWorkOrderCostFormat.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come si scrivono e si leggono importi e quantità dei costi. Il backend non dice la valuta: si usa
//  quella della lingua del telefono, euro se non c'è. I numeri scritti a mano accettano la virgola.
//

import Foundation

enum AdminWorkOrderCostFormat {
    static var currencyCode: String { Locale.current.currency?.identifier ?? "EUR" }

    /// "€ 45,00".
    static func money(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode))
    }

    /// "2", "1,5": senza decimali inutili.
    static func quantity(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    /// "In stock: 5 pcs", o "Non-stock" per un ricambio fuori magazzino.
    static func stock(of part: AdminWorkOrderPartOption) -> String? {
        if part.nonStock { return String(localized: "Non-stock") }
        guard let stock = part.stockQuantity else { return nil }
        let amount = AdminWorkOrderFormat.joined([quantity(stock), part.unit])
        return String(localized: "In stock: \(amount)")
    }

    /// Un numero scritto dall'utente ("12,50" o "12.50"); `nil` se vuoto o non valido.
    static func number(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }

    /// Un numero da rimettere in un campo di testo.
    static func editable(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }

    /// Il campo è vuoto.
    static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

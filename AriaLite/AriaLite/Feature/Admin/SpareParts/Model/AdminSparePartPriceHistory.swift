//
//  AdminSparePartPriceHistory.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  GET /v1/spare-parts/{id}/price-history: i costi unitari presi dai ricambi usati negli ordini di lavoro.
//  L'OpenAPI non descrive la risposta: si accetta un array o un oggetto che lo avvolge, e per ogni riga
//  i nomi più probabili (`unit_cost` come in WOPartUsage, `quantity`, una data, l'ordine di lavoro).
//

import Foundation

nonisolated struct AdminSparePartPriceEntry: Sendable, Identifiable, Hashable {
    let id: String
    let date: Date?
    let unitCost: Double?
    let quantity: Double?
    /// Codice, titolo o id dell'ordine di lavoro che ha usato il ricambio.
    let workOrder: String?
}

nonisolated struct AdminSparePartPriceHistory: Decodable, Sendable {
    /// Dalla più recente; senza data in fondo.
    let entries: [AdminSparePartPriceEntry]

    private static let listKeys = ["history", "priceHistory", "items", "entries", "records", "data", "usages"]
    private static let dateKeys = ["date", "usedAt", "createdAt", "recordedAt", "timestamp", "updatedAt"]
    private static let costKeys = ["unitCost", "unitPrice", "price", "cost"]
    private static let workOrderKeys = ["workOrderCode", "workOrderNumber", "workOrderTitle", "workOrderId", "woId"]

    init(from decoder: any Decoder) throws {
        let json = try decoder.singleValueContainer().decode(AriaJSON.self)
        entries = Self.entries(in: json)
    }

    static func entries(in json: AriaJSON) -> [AdminSparePartPriceEntry] {
        let rows: [AriaJSON]
        if case .array(let items) = json {
            rows = items
        } else {
            rows = listKeys.lazy.compactMap { AdminSparePartWireReader.value($0, in: json)?.arrayValue }
                .first { !$0.isEmpty } ?? []
        }
        let parsed = rows.enumerated().compactMap { index, row -> AdminSparePartPriceEntry? in
            guard row.objectValue != nil else { return nil }
            func first(_ keys: [String]) -> AriaJSON? {
                keys.lazy.compactMap { AdminSparePartWireReader.value($0, in: row) }.first
            }
            let cost = first(costKeys)?.doubleValue
            let date = first(dateKeys)?.stringValue.flatMap(AriaWireDate.parse)
            // Una riga senza costo né data non dice niente sul prezzo.
            guard cost != nil || date != nil else { return nil }
            return AdminSparePartPriceEntry(
                // La posizione e non l'id del server: la riga potrebbe non averlo, o ripeterlo.
                id: "\(index)",
                date: date,
                unitCost: cost,
                quantity: AdminSparePartWireReader.value("quantity", in: row)?.doubleValue,
                workOrder: first(workOrderKeys)?.nonEmptyString
            )
        }
        return parsed.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }
}

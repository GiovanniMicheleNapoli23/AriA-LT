//
//  AdminSparePartsAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Rotte dei ricambi e dei fornitori per un account della piattaforma (pagine /spare-parts della web).
//  Body e risposte in snake_case (`.snakeCased()`), i modelli restano in camelCase.
//

import Foundation

nonisolated struct AdminSparePartsAPI: Sendable {
    let api: AriaAPIClient

    private let parts = "v1/spare-parts"

    /// GET con i parametri facoltativi: quelli `nil` non si mandano.
    private func get<Response>(_ path: String, _ query: [String: String?] = [:]) -> AriaEndpoint<Response> {
        let items = query.sorted { $0.key < $1.key }.compactMap { key, value in
            value.map { URLQueryItem(name: key, value: $0) }
        }
        return AriaEndpoint(method: "GET", path: path, query: items).snakeCased()
    }

    // MARK: Ricambi

    func list(status: String? = nil, plantId: String?) async throws -> [AdminSparePart] {
        let rows: AdminSparePartRows<AdminSparePart> = try await api.call(get(parts, ["status": status, "plant_id": plantId]))
        return rows.items
    }

    /// `stock_quantity <= min_quantity`, oppure 0. La risposta non è descritta nell'OpenAPI: array o oggetto che lo avvolge.
    func lowStock(plantId: String?) async throws -> [AdminSparePart] {
        let rows: AdminSparePartRows<AdminSparePart> = try await api.call(get("\(parts)/low-stock", ["plant_id": plantId]))
        return rows.items
    }

    func part(id: String) async throws -> AdminSparePart {
        try await api.call(get("\(parts)/\(id)"))
    }

    func priceHistory(id: String) async throws -> [AdminSparePartPriceEntry] {
        let history: AdminSparePartPriceHistory = try await api.call(get("\(parts)/\(id)/price-history"))
        return history.entries
    }

    func create(_ body: AdminSparePartCreate) async throws -> AdminSparePart {
        try await api.call(.post(parts, body: body).snakeCased())
    }

    func update(id: String, _ body: AdminSparePartUpdate) async throws -> AdminSparePart {
        try await api.call(.patch("\(parts)/\(id)", body: body).snakeCased())
    }

    // MARK: Fornitori

    /// Tutti i fornitori dell'azienda: un ricambio può avere un fornitore che non è dello stabilimento.
    func vendors() async throws -> [AdminSparePartVendor] {
        let rows: AdminSparePartRows<AdminSparePartVendor> = try await api.call(get("v1/vendors"))
        return rows.items
    }
}

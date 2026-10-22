//
//  AdminWorkOrdersAPI+Costs.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I costi di un ordine: manodopera, ricambi usati e costi aggiuntivi, più i ricambi del magazzino da
//  scegliere. Le risposte di queste rotte non sono descritte nell'OpenAPI: le liste si leggono come array
//  o come oggetto che le avvolge, e le risposte di POST, PATCH e DELETE non si leggono (la sezione si
//  ricarica dopo ogni modifica).
//

import Foundation

nonisolated extension AdminWorkOrdersAPI {
    private func costs(_ orderId: String, _ section: String) -> String { "\(root)/\(orderId)/\(section)" }

    // MARK: Manodopera

    func labor(_ orderId: String) async throws -> [AdminWorkOrderLaborEntry] {
        let rows: AdminWorkOrderCostRows<AdminWorkOrderLaborEntry> = try await api.call(.get(costs(orderId, "labor")).snakeCased())
        return rows.items
    }

    func addLabor(_ orderId: String, _ body: AdminWorkOrderLaborCreate) async throws {
        let _: AriaNoContent = try await api.call(.post(costs(orderId, "labor"), body: body).snakeCased())
    }

    func deleteLabor(_ orderId: String, entryId: String) async throws {
        let _: AriaNoContent = try await api.call(.delete("\(costs(orderId, "labor"))/\(entryId)").snakeCased())
    }

    // MARK: Ricambi usati

    func partsUsed(_ orderId: String) async throws -> [AdminWorkOrderPartUsage] {
        let rows: AdminWorkOrderCostRows<AdminWorkOrderPartUsage> = try await api.call(.get(costs(orderId, "parts-used")).snakeCased())
        return rows.items
    }

    func addPartUsage(_ orderId: String, _ body: AdminWorkOrderPartUsageCreate) async throws {
        let _: AriaNoContent = try await api.call(.post(costs(orderId, "parts-used"), body: body).snakeCased())
    }

    func updatePartUsage(_ orderId: String, entryId: String, _ body: AdminWorkOrderPartUsageUpdate) async throws {
        let _: AriaNoContent = try await api.call(.patch("\(costs(orderId, "parts-used"))/\(entryId)", body: body).snakeCased())
    }

    func deletePartUsage(_ orderId: String, entryId: String) async throws {
        let _: AriaNoContent = try await api.call(.delete("\(costs(orderId, "parts-used"))/\(entryId)").snakeCased())
    }

    // MARK: Costi aggiuntivi

    func additionalCosts(_ orderId: String) async throws -> [AdminWorkOrderCostExtra] {
        let rows: AdminWorkOrderCostRows<AdminWorkOrderCostExtra> =
            try await api.call(.get(costs(orderId, "additional-costs")).snakeCased())
        return rows.items
    }

    func addAdditionalCost(_ orderId: String, _ body: AdminWorkOrderCostExtraCreate) async throws {
        let _: AriaNoContent = try await api.call(.post(costs(orderId, "additional-costs"), body: body).snakeCased())
    }

    func deleteAdditionalCost(_ orderId: String, entryId: String) async throws {
        let _: AriaNoContent = try await api.call(.delete("\(costs(orderId, "additional-costs"))/\(entryId)").snakeCased())
    }

    // MARK: Ricambi del magazzino

    /// I ricambi dello stabilimento (tutti, se non ce n'è uno attivo).
    func partOptions(plantId: String?) async throws -> [AdminWorkOrderPartOption] {
        let query = plantId.map { [URLQueryItem(name: "plant_id", value: $0)] } ?? []
        let rows: AdminWorkOrderCostRows<AdminWorkOrderPartOption> =
            try await api.call(AriaEndpoint(method: "GET", path: "v1/spare-parts", query: query).snakeCased())
        return rows.items
    }
}

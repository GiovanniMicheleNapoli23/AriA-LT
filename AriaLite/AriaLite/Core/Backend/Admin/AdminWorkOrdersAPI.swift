//
//  AdminWorkOrdersAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte degli ordini di lavoro per gli account della piattaforma (owner/admin/member), come la pagina
//  /work-orders della web. Tutte `.snakeCased()`: body e risposte in snake_case, modelli in camelCase.
//  Le liste passano da AriaLossyArray: una riga che non si legge si scarta, non svuota la pagina.
//

import Foundation

nonisolated struct AdminWorkOrdersAPI: Sendable {
    let api: AriaAPIClient

    private let root = "v1/work-orders"

    // MARK: Ordini

    func list(_ query: AdminWorkOrderQuery) async throws -> [AdminWorkOrder] {
        let page: AriaLossyArray<AdminWorkOrder> = try await api.call(AriaEndpoint(method: "GET", path: root, query: query.items).snakeCased())
        return page.items
    }

    func detail(_ id: String) async throws -> AdminWorkOrder {
        try await api.call(.get("\(root)/\(id)", query: ["include": "procedure"]).snakeCased())
    }

    func stepReports(_ id: String) async throws -> [AdminWorkOrderStepReport] {
        let rows: AriaLossyArray<AdminWorkOrderStepReport> = try await api.call(.get("\(root)/\(id)/step-reports").snakeCased())
        return rows.items
    }

    func create(_ body: AdminWorkOrderCreate) async throws -> AdminWorkOrder {
        try await api.call(.post(root, body: body).snakeCased())
    }

    func update(_ id: String, _ body: AdminWorkOrderUpdate) async throws -> AdminWorkOrder {
        try await api.call(.patch("\(root)/\(id)", body: body).snakeCased())
    }

    func delete(_ id: String) async throws {
        let _: AriaNoContent = try await api.call(.delete("\(root)/\(id)").snakeCased())
    }

    // MARK: Anagrafiche per il form

    func users() async throws -> [AdminWorkOrderUser] {
        let rows: AriaLossyArray<AdminWorkOrderUser> = try await api.call(.get("v1/users", query: ["active_only": "true"]).snakeCased())
        return rows.items
    }

    func teams(plantId: String?) async throws -> [AdminWorkOrderTeam] {
        let query = plantId.map { [URLQueryItem(name: "plant_id", value: $0)] } ?? []
        let rows: AriaLossyArray<AdminWorkOrderTeam> = try await api.call(AriaEndpoint(method: "GET", path: "v1/teams", query: query).snakeCased())
        return rows.items
    }

    func assets() async throws -> [AdminWorkOrderAsset] {
        let rows: AriaLossyArray<AdminWorkOrderAsset> = try await api.call(.get("v1/assets").snakeCased())
        return rows.items
    }
}

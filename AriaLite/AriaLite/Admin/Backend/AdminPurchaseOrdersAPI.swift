//
//  AdminPurchaseOrdersAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Rotte degli ordini di acquisto per un account della piattaforma (pagine /purchase-orders della web).
//  Body e risposte in snake_case (`.snakeCased()`), i modelli restano in camelCase. La lista passa da
//  AriaLossyArray: una riga che non si legge si scarta, non svuota la pagina. I fornitori per i selettori
//  vengono da `AdminSparePartsAPI.vendors()`, non da qui.
//

import Foundation

nonisolated struct AdminPurchaseOrdersAPI: Sendable {
    let api: AriaAPIClient

    private let root = "v1/purchase-orders"

    /// GET con i parametri facoltativi: quelli `nil` non si mandano.
    private func get<Response>(_ path: String, _ query: [String: String?] = [:]) -> AriaEndpoint<Response> {
        let items = query.sorted { $0.key < $1.key }.compactMap { key, value in
            value.map { URLQueryItem(name: key, value: $0) }
        }
        return AriaEndpoint(method: "GET", path: path, query: items).snakeCased()
    }

    // MARK: Ordini

    func list(plantId: String?, status: String?, vendorId: String?) async throws -> [AdminPurchaseOrder] {
        let rows: AriaLossyArray<AdminPurchaseOrder> = try await api.call(
            get(root, ["plant_id": plantId, "status": status, "vendor_id": vendorId]))
        return rows.items
    }

    func create(_ body: AdminPurchaseOrderCreate) async throws -> AdminPurchaseOrder {
        try await api.call(.post(root, body: body).snakeCased())
    }

    func order(id: String) async throws -> AdminPurchaseOrder {
        try await api.call(get("\(root)/\(id)"))
    }

    func update(id: String, _ body: AdminPurchaseOrderUpdate) async throws -> AdminPurchaseOrder {
        try await api.call(.patch("\(root)/\(id)", body: body).snakeCased())
    }

    func delete(id: String) async throws {
        let _: AriaNoContent = try await api.call(.delete("\(root)/\(id)").snakeCased())
    }

    // MARK: Righe

    func addLine(orderId: String, _ body: AdminPurchaseOrderLineCreate) async throws -> AdminPurchaseOrderLine {
        try await api.call(.post("\(root)/\(orderId)/lines", body: body).snakeCased())
    }

    func removeLine(orderId: String, lineId: String) async throws {
        let _: AriaNoContent = try await api.call(.delete("\(root)/\(orderId)/lines/\(lineId)").snakeCased())
    }

    // MARK: Transizioni di stato

    /// `approved_by` è un query parameter obbligatorio (l'id dell'utente che approva), il body è vuoto.
    func approve(id: String, approvedBy: String) async throws -> AdminPurchaseOrder {
        let endpoint = AriaEndpoint<AdminPurchaseOrder>(
            method: "POST",
            path: "\(root)/\(id)/approve",
            query: [URLQueryItem(name: "approved_by", value: approvedBy)]
        )
        return try await api.call(endpoint.snakeCased())
    }

    func reject(id: String) async throws -> AdminPurchaseOrder {
        try await api.call(.post("\(root)/\(id)/reject").snakeCased())
    }

    func receive(id: String) async throws -> AdminPurchaseOrder {
        try await api.call(.post("\(root)/\(id)/receive").snakeCased())
    }

    // MARK: Membri

    /// Il membro che ha approvato l'ordine: serve solo a mostrarne il nome.
    func member(userId: String) async throws -> AdminPurchaseOrderMember {
        try await api.call(get("v1/members/\(userId)"))
    }
}

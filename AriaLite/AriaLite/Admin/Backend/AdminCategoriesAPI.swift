//
//  AdminCategoriesAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Rotte delle categorie (pagina /categories della web). Body e risposte in snake_case (`.snakeCased()`),
//  i modelli restano in camelCase. `entity_type` è testo libero nello schema (nessun elenco di valori).
//

import Foundation

nonisolated struct AdminCategoriesAPI: Sendable {
    let api: AriaAPIClient

    private let categories = "v1/categories"

    /// GET /v1/categories: una riga illeggibile si salta, le altre restano. I filtri `nil` non si mandano.
    func list(entityType: String? = nil, plantId: String? = nil) async throws -> [AdminCategory] {
        var query: [URLQueryItem] = []
        if let entityType { query.append(URLQueryItem(name: "entity_type", value: entityType)) }
        if let plantId { query.append(URLQueryItem(name: "plant_id", value: plantId)) }
        let endpoint: AriaEndpoint<AriaLossyArray<AdminCategory>> =
            AriaEndpoint(method: "GET", path: categories, query: query).snakeCased()
        return try await api.call(endpoint).items
    }

    func create(_ body: AdminCategoryCreate) async throws -> AdminCategory {
        try await api.call(.post(categories, body: body).snakeCased())
    }

    func update(id: String, _ body: AdminCategoryUpdate) async throws -> AdminCategory {
        try await api.call(.patch("\(categories)/\(id)", body: body).snakeCased())
    }

    /// DELETE /v1/categories/{id}: la risposta non serve.
    func delete(id: String) async throws {
        let endpoint = AriaEndpoint<AriaNoContent>.delete("\(categories)/\(id)").snakeCased()
        let _: AriaNoContent = try await api.call(endpoint)
    }
}

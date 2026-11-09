//
//  AdminPlantsAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Rotte degli stabilimenti per un account della piattaforma (pagina /plants della web).
//  Body e risposte in snake_case (`.snakeCased()`), i modelli restano in camelCase.
//

import Foundation

nonisolated struct AdminPlantsAPI: Sendable {
    let api: AriaAPIClient

    private let plants = "v1/plants"

    /// GET /v1/plants: array di righe; una riga illeggibile si salta, le altre restano.
    func list() async throws -> [AdminPlant] {
        let endpoint: AriaEndpoint<AriaLossyArray<AdminPlant>> =
            AriaEndpoint(method: "GET", path: plants).snakeCased()
        return try await api.call(endpoint).items
    }

    func create(_ body: AdminPlantCreate) async throws -> AdminPlant {
        try await api.call(.post(plants, body: body).snakeCased())
    }

    func update(id: String, _ body: AdminPlantUpdate) async throws -> AdminPlant {
        try await api.call(.patch("\(plants)/\(id)", body: body).snakeCased())
    }

    /// DELETE /v1/plants/{id}: la risposta non serve.
    func delete(id: String) async throws {
        let _: AriaNoContent = try await api.call(AriaEndpoint<AriaNoContent>.delete("\(plants)/\(id)").snakeCased())
    }
}

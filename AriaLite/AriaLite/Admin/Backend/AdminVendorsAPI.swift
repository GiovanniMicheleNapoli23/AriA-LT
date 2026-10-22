//
//  AdminVendorsAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Rotte dei fornitori per un account della piattaforma (pagine /vendors e /vendors/{id} della web).
//  Body e risposte in snake_case (`.snakeCased()`), i modelli restano in camelCase.
//

import Foundation

nonisolated struct AdminVendorsAPI: Sendable {
    let api: AriaAPIClient

    private let vendors = "v1/vendors"

    /// GET /v1/vendors: array di righe; una riga illeggibile si salta, le altre restano.
    /// I parametri `nil` non si mandano.
    func list(plantId: String?, vendorType: String? = nil) async throws -> [AdminVendor] {
        var query: [URLQueryItem] = []
        if let plantId { query.append(URLQueryItem(name: "plant_id", value: plantId)) }
        if let vendorType { query.append(URLQueryItem(name: "vendor_type", value: vendorType)) }
        let endpoint: AriaEndpoint<AriaLossyArray<AdminVendor>> =
            AriaEndpoint(method: "GET", path: vendors, query: query).snakeCased()
        return try await api.call(endpoint).items
    }

    func vendor(id: String) async throws -> AdminVendor {
        try await api.call(AriaEndpoint<AdminVendor>.get("\(vendors)/\(id)").snakeCased())
    }

    func create(_ body: AdminVendorCreate) async throws -> AdminVendor {
        try await api.call(.post(vendors, body: body).snakeCased())
    }

    func update(id: String, _ body: AdminVendorUpdate) async throws -> AdminVendor {
        try await api.call(.patch("\(vendors)/\(id)", body: body).snakeCased())
    }

    /// DELETE /v1/vendors/{id}: la risposta non serve.
    func delete(id: String) async throws {
        let _: AriaNoContent = try await api.call(AriaEndpoint<AriaNoContent>.delete("\(vendors)/\(id)").snakeCased())
    }
}

//
//  AdminAuditLogAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Storico delle modifiche dell'azienda (GET /v1/audit-log, la pagina /audit-log della web) e i nomi di chi
//  le ha fatte (GET /v1/users). Tutto in snake_case: `.snakeCased()`.
//

import Foundation

nonisolated struct AdminAuditLogAPI: Sendable {
    let api: AriaAPIClient

    /// GET /v1/audit-log, dalla modifica più recente. I filtri `nil` non si mandano.
    /// Il server non filtra per data né per utente: quei controlli lavorano sulle righe scaricate.
    func page(entityType: String?, action: String?, offset: Int, limit: Int) async throws -> AdminAuditLogPage {
        var query = [
            URLQueryItem(name: "sort_order", value: "desc"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        if let entityType { query.append(URLQueryItem(name: "entity_type", value: entityType)) }
        if let action { query.append(URLQueryItem(name: "action", value: action)) }
        let endpoint: AriaEndpoint<AdminAuditLogPage> =
            AriaEndpoint(method: "GET", path: "v1/audit-log", query: query).snakeCased()
        return try await api.call(endpoint)
    }

    /// GET /v1/users con anche i disattivati: chi ha fatto una modifica può non essere più attivo.
    /// Se il ruolo non li vede, chi chiama mostra gli id.
    func users() async throws -> [AdminAuditLogUser] {
        let endpoint: AriaEndpoint<AriaLossyArray<AdminAuditLogUser>> =
            AriaEndpoint(method: "GET", path: "v1/users", query: [URLQueryItem(name: "active_only", value: "false")])
                .snakeCased()
        return try await api.call(endpoint).items
    }
}

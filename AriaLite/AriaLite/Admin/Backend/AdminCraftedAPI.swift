//
//  AdminCraftedAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte della sezione Crafted (pagina /crafted della web): le sessioni concluse con il loro verdetto.
//  Messaggi, rinomina e report .docx delle sessioni stanno in AriaChatAPI e si riusano da lì; i widget
//  salvati stanno in AdminReportsAPI. Gli artifact fatti da Crafted non hanno rotte: si tengono sul dispositivo.
//

import Foundation

nonisolated enum AdminCraftedAPI {
    // MARK: Sessioni concluse

    /// GET /v1/companies/{id}/session-reviews: le sessioni concluse con verdetto, passi e cose imparate.
    /// Risposta in camelCase (`sessionId`, `verdictSource`), il filtro invece è `plant_id`.
    static func sessionReviews(companyId: String, plantId: String?, limit: Int = 200) -> AriaEndpoint<AdminCraftedSessionReviews> {
        var query = [URLQueryItem(name: "limit", value: "\(min(max(limit, 1), 500))")]
        if let plantId { query.append(URLQueryItem(name: "plant_id", value: plantId)) }
        return AriaEndpoint(method: "GET", path: "v1/companies/\(companyId)/session-reviews", query: query)
    }
}

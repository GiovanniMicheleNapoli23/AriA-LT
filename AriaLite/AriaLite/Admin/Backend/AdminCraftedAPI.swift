//
//  AdminCraftedAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte della sezione Crafted (pagina /crafted della web): i widget salvati dalle card di Aria e le
//  sessioni concluse con il loro verdetto. Messaggi, rinomina e report .docx delle sessioni stanno in
//  AriaChatAPI e si riusano da lì.
//

import Foundation

nonisolated enum AdminCraftedAPI {
    // MARK: Widget salvati

    /// GET /v1/saved-widgets: i widget dell'utente. Niente `.snakeCased()`: convertirebbe anche le chiavi
    /// di `tool_args`, che il tool vuole identiche (i modelli hanno le loro CodingKeys).
    static func widgets() -> AriaEndpoint<AriaLossyArray<AdminCraftedWidget>> {
        .get("v1/saved-widgets")
    }

    /// POST /v1/saved-widgets: fissa una card di Aria (tipo, tool e argomenti) fra i widget.
    static func createWidget(_ body: AdminCraftedWidgetCreate) -> AriaEndpoint<AdminCraftedWidget> {
        .post("v1/saved-widgets", body: body)
    }

    static func deleteWidget(id: String) -> AriaEndpoint<AriaNoContent> {
        .delete("v1/saved-widgets/\(id)")
    }

    /// POST /v1/saved-widgets/{id}/render: riesegue il tool del widget e dà i dati di oggi.
    /// La forma della risposta non è documentata: si legge libera (AdminCraftedRender). Le chiavi restano
    /// come arrivano (`x_key`, `row_link_template`…): le card della chat le leggono così.
    static func render(widgetId: String, plantId: String?) -> AriaEndpoint<AriaJSON> {
        AriaEndpoint(method: "POST", path: "v1/saved-widgets/\(widgetId)/render",
                     query: plantId.map { [URLQueryItem(name: "plantId", value: $0)] } ?? [])
    }

    // MARK: Sessioni concluse

    /// GET /v1/companies/{id}/session-reviews: le sessioni concluse con verdetto, passi e cose imparate.
    /// Risposta in camelCase (`sessionId`, `verdictSource`), il filtro invece è `plant_id`.
    static func sessionReviews(companyId: String, plantId: String?, limit: Int = 200) -> AriaEndpoint<AdminCraftedSessionReviews> {
        var query = [URLQueryItem(name: "limit", value: "\(min(max(limit, 1), 500))")]
        if let plantId { query.append(URLQueryItem(name: "plant_id", value: plantId)) }
        return AriaEndpoint(method: "GET", path: "v1/companies/\(companyId)/session-reviews", query: query)
    }
}

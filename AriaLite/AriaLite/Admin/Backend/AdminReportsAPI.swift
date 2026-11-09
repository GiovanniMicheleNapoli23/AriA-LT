//
//  AdminReportsAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte della sezione Reports (pagina /reports della web): panoramica, ordini di lavoro e asset, tutte
//  con il filtro per stabilimento, e i widget salvati (le card di Aria fissate dall'utente).
//

import Foundation

nonisolated enum AdminReportsAPI {
    /// GET /v1/reports/overview. Niente `.snakeCased()`: i modelli hanno le loro CodingKeys e le chiavi
    /// delle ripartizioni (`in_progress`…) devono restare com'è.
    static func overview(plantId: String?) -> AriaEndpoint<AdminReportOverview> {
        report("overview", plantId: plantId)
    }

    /// GET /v1/reports/work-orders: ripartizioni e andamento dei completamenti (gli ultimi 6 mesi).
    static func workOrders(plantId: String?) -> AriaEndpoint<AdminReportWorkOrders> {
        report("work-orders", plantId: plantId)
    }

    /// GET /v1/reports/assets: ripartizioni e asset con più guasti.
    static func assets(plantId: String?) -> AriaEndpoint<AdminReportAssets> {
        report("assets", plantId: plantId)
    }

    /// GET /v1/assets: serve solo a dare un nome alle righe di `top_failing` che non lo hanno.
    static func assetNames() -> AriaEndpoint<AriaLossyArray<AdminAsset>> {
        AdminAssetsAPI.assets(status: nil)
    }

    /// `plant_id` si manda solo se c'è: senza, il report copre tutti gli stabilimenti.
    private static func report<Response: Decodable & Sendable>(
        _ name: String, plantId: String?
    ) -> AriaEndpoint<Response> {
        AriaEndpoint(method: "GET", path: "v1/reports/\(name)",
                     query: plantId.map { [URLQueryItem(name: "plant_id", value: $0)] } ?? [])
    }

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
}

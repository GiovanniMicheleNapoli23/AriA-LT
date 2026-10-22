//
//  AdminReportsAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte della sezione Reports (pagina /reports della web): panoramica, ordini di lavoro e asset, tutte
//  con il filtro per stabilimento. I widget salvati stanno in AdminCraftedAPI e si riusano da lì.
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
}

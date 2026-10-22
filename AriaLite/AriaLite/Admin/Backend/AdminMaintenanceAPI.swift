//
//  AdminMaintenanceAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte della sezione Maintenance degli account della piattaforma, come le pagine /maintenance e
//  /maintenance/{id} della web. Una riga per rotta; si eseguono con `backend.api.call(endpoint)`.
//  Tutte in snake_case: body e risposte si convertono, i modelli restano in camelCase.
//  Allegati e storico sono in AdminMaintenanceAPI+Activity.swift.
//

import Foundation

nonisolated enum AdminMaintenanceAPI {
    // MARK: Piani

    /// GET /v1/maintenance-plans. Senza `status` il server dà solo gli `approved`: "tutti" non esiste come valore.
    static func plans(status: String?) -> AriaEndpoint<AriaLossyArray<AdminMaintenancePlan>> {
        get("v1/maintenance-plans", ["status": status])
    }

    static func plan(id: String) -> AriaEndpoint<AdminMaintenancePlan> {
        AriaEndpoint.get("v1/maintenance-plans/\(id)").snakeCased()
    }

    static func create(_ body: AdminMaintenancePlanCreate) -> AriaEndpoint<AdminMaintenancePlan> {
        AriaEndpoint.post("v1/maintenance-plans", body: body).snakeCased()
    }

    static func update(id: String, _ changes: AdminPatchBody) -> AriaEndpoint<AdminMaintenancePlan> {
        AriaEndpoint.patch("v1/maintenance-plans/\(id)", body: changes.fields).snakeCased()
    }

    /// POST …/ai-improve. Risposta non documentata (`{}`): si legge libera, vedi AdminMaintenanceProposal.
    static func aiImprove(id: String, _ body: AdminMaintenanceImproveRequest) -> AriaEndpoint<AriaJSON> {
        AriaEndpoint.post("v1/maintenance-plans/\(id)/ai-improve", body: body).snakeCased()
    }

    // MARK: Contorno

    /// Le persone dell'azienda, per dare un nome agli id dello storico e degli allegati.
    static func users() -> AriaEndpoint<AriaLossyArray<AdminWorkOrderUser>> {
        get("v1/users", ["active_only": "true"])
    }

    /// Gli asset approvati, per scegliere quello del piano.
    static func assets() -> AriaEndpoint<AriaLossyArray<AdminWorkOrderAsset>> {
        get("v1/assets", ["status": "approved"])
    }

    /// GET /v1/work-orders. La rotta non ha un filtro per piano (ma ogni ordine ha `maintenance_plan_id`):
    /// si chiedono quelli dell'asset (o dello stabilimento), aperti e chiusi, e si filtra qui.
    static func workOrders(assetTag: String?, plantId: String?) -> AriaEndpoint<AriaLossyArray<AdminMaintenanceWorkOrder>> {
        get("v1/work-orders", [
            "status_group": "all",
            "asset_tag": assetTag,
            "plant_id": plantId,
            "limit": "200",
        ])
    }

    /// GET con i soli parametri presenti (`AriaEndpoint.get` non salta i nil).
    private static func get<Response: Decodable & Sendable>(_ path: String, _ query: KeyValuePairs<String, String?>) -> AriaEndpoint<Response> {
        let items = query.compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } }
        return AriaEndpoint(method: "GET", path: path, query: items).snakeCased()
    }
}

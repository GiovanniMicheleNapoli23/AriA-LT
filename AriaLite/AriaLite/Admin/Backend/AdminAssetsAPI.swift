//
//  AdminAssetsAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte della sezione Assets degli account della piattaforma (owner, admin, member), come le pagine
//  /assets e /assets/{tag} della web. Una riga per rotta; si eseguono con `backend.api.call(endpoint)`.
//  Tutte in snake_case: body e risposte si convertono, i modelli restano in camelCase.
//  Un ruolo che non può (member su una scrittura) riceve 403: lo traduce chi chiama, senza uscire dall'account.
//

import Foundation

nonisolated enum AdminAssetsAPI {
    // MARK: Asset

    /// GET /v1/assets. Senza `status` il server dà solo gli `approved`: "tutti" non esiste come valore.
    static func assets(status: String?, assetType: String? = nil, zone: String? = nil) -> AriaEndpoint<AriaLossyArray<AdminAsset>> {
        get("v1/assets", ["status": status, "asset_type": assetType, "zone": zone])
    }

    static func asset(tag: String) -> AriaEndpoint<AdminAsset> {
        AriaEndpoint.get("v1/assets/by-tag/\(tag)").snakeCased()
    }

    static func create(_ body: AdminAssetCreate) -> AriaEndpoint<AdminAsset> {
        AriaEndpoint.post("v1/assets", body: body).snakeCased()
    }

    static func update(assetId: String, _ changes: AdminPatchBody) -> AriaEndpoint<AdminAsset> {
        AriaEndpoint.patch("v1/assets/\(assetId)", body: changes.fields).snakeCased()
    }

    // MARK: Fermi

    /// Statistiche degli ultimi 30 giorni: forma non documentata, si legge libera (AdminDowntimeStats).
    static func downtimeStats(assetTag: String) -> AriaEndpoint<AriaJSON> {
        AriaEndpoint.get("v1/asset-downtime/stats/\(assetTag)").snakeCased()
    }

    static func downtimes(assetTag: String, plantId: String?) -> AriaEndpoint<AriaLossyArray<AdminDowntime>> {
        get("v1/asset-downtime", ["asset_tag": assetTag, "plant_id": plantId])
    }

    static func createDowntime(_ body: AdminDowntimeCreate) -> AriaEndpoint<AdminDowntime> {
        AriaEndpoint.post("v1/asset-downtime", body: body).snakeCased()
    }

    static func updateDowntime(id: String, _ changes: AdminPatchBody) -> AriaEndpoint<AdminDowntime> {
        AriaEndpoint.patch("v1/asset-downtime/\(id)", body: changes.fields).snakeCased()
    }

    static func deleteDowntime(id: String) -> AriaEndpoint<AriaNoContent> {
        AriaEndpoint.delete("v1/asset-downtime/\(id)").snakeCased()
    }

    // MARK: Ordini di lavoro dell'asset

    /// Aperti e chiusi, i più recenti del server (massimo 200).
    static func workOrders(assetTag: String, limit: Int = 50) -> AriaEndpoint<AriaLossyArray<AdminAssetWorkOrder>> {
        get("v1/work-orders", ["asset_tag": assetTag, "status_group": "all", "limit": "\(min(max(limit, 1), 200))"])
    }

    /// GET con i soli parametri presenti (`AriaEndpoint.get` non salta i nil).
    private static func get<Response: Decodable & Sendable>(_ path: String, _ query: KeyValuePairs<String, String?>) -> AriaEndpoint<Response> {
        let items = query.compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } }
        return AriaEndpoint(method: "GET", path: path, query: items).snakeCased()
    }
}

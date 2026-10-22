//
//  AdminExtractionReviewAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte della pagina /extraction/review che Assets e Spare Parts non hanno già: allarmi, piani di
//  manutenzione, approvazione in blocco e AI (ai-improve / ai-analyze). Lista, modifica e lettura di asset
//  e ricambi passano da AdminAssetsAPI e AdminSparePartsAPI. Tutte in snake_case (`.snakeCased()`).
//
//  Due cose che l'OpenAPI non descrive, quindi IPOTESI:
//  - il body di bulk-approve (`additionalProperties: true`): si mandano gli id sia come `ids` sia come
//    `<entità>_ids` (stessa convenzione di `company_ids` nelle rotte bulk della piattaforma);
//  - le risposte di bulk-approve e delle rotte AI: si leggono come JSON libero.
//

import Foundation

nonisolated enum AdminExtractionReviewAPI {
    // MARK: Allarmi

    /// GET /v1/alarms. Senza `status` il server dà solo gli `approved`.
    static func alarms(status: String) -> AriaEndpoint<AriaLossyArray<AdminExtractionAlarm>> {
        get("v1/alarms", ["status": status])
    }

    /// GET /v1/alarms/by-id/{alarm_id}: per id. La rotta senza `by-id` sembra cercare per codice, non si usa.
    static func alarm(id: String) -> AriaEndpoint<AdminExtractionAlarm> {
        AriaEndpoint.get("v1/alarms/by-id/\(id)").snakeCased()
    }

    static func updateAlarm(id: String, _ changes: AdminPatchBody) -> AriaEndpoint<AdminExtractionAlarm> {
        AriaEndpoint.patch("v1/alarms/\(id)", body: changes.fields).snakeCased()
    }

    /// POST /v1/alarms/bulk-approve: approva e sincronizza la conoscenza.
    static func approveAlarms(ids: [String]) -> AriaEndpoint<AriaJSON> {
        AriaEndpoint.post("v1/alarms/bulk-approve", body: AdminExtractionBulkApproveBody(ids: ids, entityKey: "alarm_ids"))
            .snakeCased()
    }

    static func improveAlarm(id: String, _ body: AdminExtractionAIRequest) -> AriaEndpoint<AriaJSON> {
        AriaEndpoint.post("v1/alarms/\(id)/ai-improve", body: body).snakeCased()
    }

    // MARK: Piani di manutenzione

    static func maintenancePlans(status: String) -> AriaEndpoint<AriaLossyArray<AdminExtractionMaintenancePlan>> {
        get("v1/maintenance-plans", ["status": status])
    }

    static func maintenancePlan(id: String) -> AriaEndpoint<AdminExtractionMaintenancePlan> {
        AriaEndpoint.get("v1/maintenance-plans/\(id)").snakeCased()
    }

    static func updateMaintenancePlan(id: String, _ changes: AdminPatchBody) -> AriaEndpoint<AdminExtractionMaintenancePlan> {
        AriaEndpoint.patch("v1/maintenance-plans/\(id)", body: changes.fields).snakeCased()
    }

    /// POST /v1/maintenance-plans/{plan_id}/ai-improve (AIImproveRequest: `step_index` non si usa, vale per tutto il piano).
    static func improveMaintenancePlan(id: String, _ body: AdminExtractionAIRequest) -> AriaEndpoint<AriaJSON> {
        AriaEndpoint.post("v1/maintenance-plans/\(id)/ai-improve", body: body).snakeCased()
    }

    // MARK: Asset e ricambi (solo quello che manca alle loro API)

    static func approveAssets(ids: [String]) -> AriaEndpoint<AriaJSON> {
        AriaEndpoint.post("v1/assets/bulk-approve", body: AdminExtractionBulkApproveBody(ids: ids, entityKey: "asset_ids"))
            .snakeCased()
    }

    static func analyzeAsset(id: String, _ body: AdminExtractionAIRequest) -> AriaEndpoint<AriaJSON> {
        AriaEndpoint.post("v1/assets/\(id)/ai-analyze", body: body).snakeCased()
    }

    /// SparePartAIRequest ha solo `action` e `custom_prompt`: la lingua non si manda.
    static func analyzeSparePart(id: String, _ body: AdminExtractionAIRequest) -> AriaEndpoint<AriaJSON> {
        var body = body
        body.language = nil
        return AriaEndpoint.post("v1/spare-parts/\(id)/ai-analyze", body: body).snakeCased()
    }

    /// GET con i soli parametri presenti (`AriaEndpoint.get` non salta i nil).
    private static func get<Response: Decodable & Sendable>(_ path: String, _ query: KeyValuePairs<String, String?>) -> AriaEndpoint<Response> {
        let items = query.compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } }
        return AriaEndpoint(method: "GET", path: path, query: items).snakeCased()
    }
}

/// Body di bulk-approve: gli stessi id sotto `ids` e sotto la chiave dell'entità (`asset_ids`, `alarm_ids`).
/// Chiavi già in snake_case: un dizionario resta com'è anche con l'encoder in snake_case.
nonisolated struct AdminExtractionBulkApproveBody: Encodable, Sendable {
    let ids: [String]
    let entityKey: String

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(["ids": ids, entityKey: ids])
    }
}

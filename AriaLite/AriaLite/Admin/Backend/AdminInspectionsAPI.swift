//
//  AdminInspectionsAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte della sezione Inspections degli account della piattaforma, come le pagine /inspections e
//  /inspections/{id} della web. Una riga per rotta; si eseguono con `backend.api.call(endpoint)`.
//  Tutte in snake_case: body e risposte si convertono, i modelli restano in camelCase.
//  La lista non ha filtri lato server: stato, stabilimento, asset, area e data si filtrano sull'app.
//  Gli stabilimenti (GET /v1/plants) arrivano da `backend.plants`.
//

import Foundation

nonisolated enum AdminInspectionsAPI {
    /// GET /v1/inspections.
    static func list() -> AriaEndpoint<AriaLossyArray<AdminInspection>> {
        AriaEndpoint.get("v1/inspections").snakeCased()
    }

    /// GET /v1/inspections/{inspection_id}.
    static func detail(id: String) -> AriaEndpoint<AdminInspection> {
        AriaEndpoint.get("v1/inspections/\(id)").snakeCased()
    }

    /// POST /v1/inspections.
    static func create(_ body: AdminInspectionCreate) -> AriaEndpoint<AdminInspection> {
        AriaEndpoint.post("v1/inspections", body: body).snakeCased()
    }

    /// PATCH /v1/inspections/{inspection_id}: solo i campi cambiati (`items` sostituisce l'intero elenco).
    static func update(id: String, _ changes: AdminPatchBody) -> AriaEndpoint<AdminInspection> {
        AriaEndpoint.patch("v1/inspections/\(id)", body: changes.fields).snakeCased()
    }

    /// DELETE /v1/inspections/{inspection_id}.
    static func delete(id: String) -> AriaEndpoint<AriaNoContent> {
        AriaEndpoint.delete("v1/inspections/\(id)").snakeCased()
    }

    /// PATCH /v1/inspections/{inspection_id}/items/{item_id}: risponde con l'ispezione intera.
    static func updateItem(inspectionId: String, itemId: String, _ change: AdminInspectionItemChange) -> AriaEndpoint<AdminInspection> {
        AriaEndpoint.patch("v1/inspections/\(inspectionId)/items/\(itemId)", body: change).snakeCased()
    }

    /// POST /v1/inspections/{inspection_id}/ai-improve: la risposta non ha schema, si legge libera.
    static func aiImprove(id: String, _ body: AdminInspectionAIRequest) -> AriaEndpoint<AriaJSON> {
        AriaEndpoint.post("v1/inspections/\(id)/ai-improve", body: body).snakeCased()
    }
}

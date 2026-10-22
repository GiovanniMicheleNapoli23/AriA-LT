//
//  AdminWorkOrdersAPI+Templates.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I modelli di ordine (/v1/work-order-templates): elenco, creazione, modifica, eliminazione e
//  "crea ordine dal modello". POST …/{id}/apply non crea l'ordine: restituisce i campi di un WorkOrderCreate,
//  che poi si mandano a POST /v1/work-orders. La risposta di apply si legge senza conversione delle chiavi,
//  così i nomi restano quelli del server, e si tengono solo i campi che WorkOrderCreate accetta.
//

import Foundation

nonisolated extension AdminWorkOrdersAPI {
    private var templates: String { "v1/work-order-templates" }

    func templateList() async throws -> [AdminWorkOrderTemplate] {
        let rows: AriaLossyArray<AdminWorkOrderTemplate> = try await api.call(.get(templates).snakeCased())
        return rows.items
    }

    func createTemplate(_ body: AdminWorkOrderTemplateCreate) async throws -> AdminWorkOrderTemplate {
        try await api.call(.post(templates, body: body).snakeCased())
    }

    func updateTemplate(_ id: String, _ body: AdminWorkOrderTemplateUpdate) async throws -> AdminWorkOrderTemplate {
        try await api.call(.patch("\(templates)/\(id)", body: body).snakeCased())
    }

    func deleteTemplate(_ id: String) async throws {
        let _: AriaNoContent = try await api.call(.delete("\(templates)/\(id)").snakeCased())
    }

    /// I campi dell'ordine che il modello propone, con le chiavi del server (snake_case).
    func applyTemplate(_ id: String) async throws -> [String: AriaJSON] {
        let fields: AriaJSON = try await api.call(.post("\(templates)/\(id)/apply"))
        guard case .object(let object) = fields else { return [:] }
        return object
    }

    /// L'ordine creato dai campi di `applyTemplate`. Restano solo quelli di WorkOrderCreate e senza `null`
    /// (un `null` su tipo, priorità o stato non passerebbe la validazione).
    func createOrder(from fields: [String: AriaJSON]) async throws -> AdminWorkOrder {
        var allowed = fields.filter { Self.workOrderCreateKeys.contains($0.key) && $0.value != .null }
        // WorkOrderCreate vuole la checklist come testo: una lista o un oggetto si scrivono in JSON.
        if let checklist = allowed["checklist_data"], Self.isStructured(checklist),
           let data = try? JSONEncoder().encode(checklist), let text = String(data: data, encoding: .utf8) {
            allowed["checklist_data"] = .string(text)
        }
        return try await api.call(.post(root, body: AriaJSON.object(allowed)).snakeCased())
    }

    private static func isStructured(_ value: AriaJSON) -> Bool {
        switch value {
        case .array, .object: true
        default: false
        }
    }

    /// Le proprietà di WorkOrderCreate nell'OpenAPI.
    static let workOrderCreateKeys: Set<String> = [
        "title", "type", "category", "priority", "status", "asset_tag", "alarm_code", "maintenance_plan_id",
        "plant_id", "zone", "description", "assigned_to", "requested_by", "assigned_to_team_id",
        "assigned_to_user_id", "estimated_duration_min", "notes", "resolution_notes", "scheduled_date",
        "due_date", "completed_date", "checklist_data", "chat_session_id",
    ]
}

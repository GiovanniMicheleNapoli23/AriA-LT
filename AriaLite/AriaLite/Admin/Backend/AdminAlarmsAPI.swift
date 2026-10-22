//
//  AdminAlarmsAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Rotte degli allarmi per un account della piattaforma (pagine /alarms e /alarms/{id} della web), con
//  l'agente di diagnosi e la creazione dell'ordine di lavoro. Body e risposte in snake_case (`.snakeCased()`),
//  i modelli restano in camelCase.
//

import Foundation

nonisolated struct AdminAlarmsAPI: Sendable {
    let api: AriaAPIClient

    private let alarms = "v1/alarms"

    /// GET /v1/alarms?status=: l'elenco di uno stato (il server dà `approved` se manca). Non ha né ricerca
    /// né pagine: si cerca sul telefono. Una riga illeggibile si salta, le altre restano.
    func list(status: String) async throws -> [AdminAlarm] {
        let endpoint: AriaEndpoint<AriaLossyArray<AdminAlarm>> = .get(alarms, query: ["status": status]).snakeCased()
        return try await api.call(endpoint).items
    }

    /// GET /v1/alarms/by-id/{id}: per id (la rotta senza `by-id` cerca per codice).
    func alarm(id: String) async throws -> AdminAlarm {
        try await api.call(AriaEndpoint<AdminAlarm>.get("\(alarms)/by-id/\(id)").snakeCased())
    }

    func update(id: String, _ body: AdminAlarmUpdate) async throws -> AdminAlarm {
        try await api.call(.patch("\(alarms)/\(id)", body: body).snakeCased())
    }

    /// POST /v1/alarms/{id}/ai-improve: la risposta non ha schema, si legge libera.
    func improve(id: String, _ body: AdminAlarmImproveRequest) async throws -> AriaJSON {
        try await api.call(.post("\(alarms)/\(id)/ai-improve", body: body).snakeCased())
    }

    /// POST /v1/alarms/bulk-approve: approva e sincronizza la conoscenza.
    func approve(ids: [String]) async throws {
        let _: AriaJSON = try await api.call(.post("\(alarms)/bulk-approve", body: AdminAlarmBulkApproveBody(ids: ids)))
    }

    /// POST /v1/agents/diagnostic.
    func diagnose(_ body: AdminAlarmDiagnosticRequest) async throws -> AdminAlarmDiagnosis {
        try await api.call(.post("v1/agents/diagnostic", body: body).snakeCased())
    }

    /// POST /v1/work-orders.
    func createWorkOrder(_ body: AdminAlarmWorkOrderCreate) async throws -> AdminAlarmCreatedWorkOrder {
        try await api.call(.post("v1/work-orders", body: body).snakeCased())
    }
}

//
//  AdminAgentStudioAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte dei workflow di Agent Studio (pagina /agent-studio della web): lista, dettaglio, attiva/disattiva,
//  storico dei run, run attivi, annulla. Questa API risponde in camelCase con pezzi in snake_case: i modelli
//  si leggono da JSON libero (AdminAgentStudioFields), quindi niente `.snakeCased()`.
//  Avvio di un run ed eventi sono stream: si leggono per intero con `api.data` e si dividono in righe.
//

import Foundation

nonisolated enum AdminAgentStudioAPI {
    // MARK: Workflow

    static func workflows() -> AriaEndpoint<AdminAgentStudioList<AdminAgentStudioWorkflow>> {
        .get("v1/agent-studio/workflows")
    }

    static func workflow(id: String) -> AriaEndpoint<AdminAgentStudioOne<AdminAgentStudioWorkflow>> {
        .get("v1/agent-studio/workflows/\(id)")
    }

    /// Il server può rifiutare l'attivazione se il workflow non ha passato il validatore (policy).
    static func setEnabled(workflowId: String, _ enabled: Bool) -> AriaEndpoint<AdminAgentStudioOne<AdminAgentStudioWorkflow>> {
        .put("v1/agent-studio/workflows/\(workflowId)/enabled", body: AdminAgentStudioEnableBody(enabled: enabled))
    }

    // MARK: Run

    static func runs(workflowId: String) -> AriaEndpoint<AdminAgentStudioList<AdminAgentStudioRun>> {
        .get("v1/agent-studio/workflows/\(workflowId)/runs")
    }

    static func run(workflowId: String, runId: String) -> AriaEndpoint<AdminAgentStudioOne<AdminAgentStudioRun>> {
        .get("v1/agent-studio/workflows/\(workflowId)/runs/\(runId)")
    }

    /// Run in corso in questo processo del server e run fermi ad aspettare una persona.
    static func activeRuns() -> AriaEndpoint<AdminAgentStudioActiveRuns> {
        .get("v1/agent-studio/workflow-runs/active")
    }

    /// Un run in corso si ferma entro un passo; uno in pausa si chiude e le sue approvazioni si ritirano.
    static func cancelRun(runId: String) -> AriaEndpoint<AriaNoContent> {
        .post("v1/agent-studio/workflow-runs/\(runId)/cancel")
    }

    // MARK: Stream

    /// POST workflow-runs: il server manda un verdetto per nodo man mano; qui si aspetta la fine dello stream.
    static func startRun(_ body: AdminAgentStudioRunBody, api: AriaAPIClient) async throws -> [AriaJSON] {
        let data = try JSONEncoder().encode(body)
        let raw = try await api.data("POST", "v1/agent-studio/workflow-runs", body: data)
        return AdminAgentStudioRunStream.lines(from: raw)
    }

    /// GET workflow-runs/{id}/events: le righe dopo `after`; finché il run è vivo la risposta resta aperta.
    static func runEvents(runId: String, after: Int = 0, api: AriaAPIClient) async throws -> [AriaJSON] {
        let raw = try await api.data("GET", "v1/agent-studio/workflow-runs/\(runId)/events",
                                     query: [URLQueryItem(name: "after", value: String(after))])
        return AdminAgentStudioRunStream.lines(from: raw)
    }
}

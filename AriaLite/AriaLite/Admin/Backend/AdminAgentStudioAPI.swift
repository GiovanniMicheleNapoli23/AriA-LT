//
//  AdminAgentStudioAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte dei workflow di Agent Studio (pagina /agent-studio della web): lista, dettaglio, attiva/disattiva,
//  storico dei run, run attivi, annulla. Questa API risponde in camelCase con pezzi in snake_case: i modelli
//  si leggono da JSON libero (AdminAgentStudioFields), quindi niente `.snakeCased()`.
//  Avvio di un run ed eventi sono stream NDJSON: le righe si consumano man mano (AriaAPIClient.ndjson).
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

    /// POST workflow-runs: il server manda una riga JSON per evento man mano che il run avanza.
    /// Lo stream non si può riprovare (rilancerebbe il run): se cade, si prosegue con `eventLines`.
    static func runLines(_ body: AdminAgentStudioRunBody, api: AriaAPIClient) -> AsyncThrowingStream<AriaJSON, any Error> {
        guard let data = try? JSONEncoder().encode(body) else {
            return AsyncThrowingStream { $0.finish(throwing: AriaError.stream(String(localized: "Invalid request."))) }
        }
        return api.ndjson("POST", "v1/agent-studio/workflow-runs", body: data)
    }

    /// L'ultima riga di uno stream aperto con un accesso poi tolto: `{"type": "permission_denied", "detail":
    /// {"code": …}}`. Diventa l'errore del 403 corrispondente (così passa dal percorso d'errore già esistente);
    /// `nil` per ogni altra riga. `not_a_member` esce come 403 generico: chi consuma decide se è la fine della sessione.
    static func accessError(in line: AriaJSON) -> AriaError? {
        guard line["type"]?.stringValue == "permission_denied" else { return nil }
        switch line["detail"]?["code"]?.stringValue {
        case "not_a_member": return .http(status: 403, detail: "not_a_member")
        case "membership_suspended": return .http(status: 403, detail: "membership_suspended")
        case "operation_forbidden": return .notOnPhone
        default: return .permissionDenied(AriaPermissionDenial(line) ?? AriaPermissionDenial())
        }
    }

    /// GET workflow-runs/{id}/events: le righe con `seq` > `after`, poi quelle nuove finché il run è vivo.
    static func eventLines(runId: String, after: Int = 0, api: AriaAPIClient) -> AsyncThrowingStream<AriaJSON, any Error> {
        api.ndjson("GET", "v1/agent-studio/workflow-runs/\(runId)/events",
                   query: [URLQueryItem(name: "after", value: String(after))])
    }
}

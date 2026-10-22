//
//  AdminWorkflowsAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte dei flussi (topologie degli agenti) della sezione Workflows, come la pagina /workflows della web.
//  ATTENZIONE: queste rotte viaggiano in camelCase (`companyId`, `definitionVersion`) e l'id è `_id`,
//  quindi niente `.snakeCased()`. Ogni azione che cambia il flusso manda la `revision` letta: se nel frattempo
//  qualcuno l'ha cambiato il server risponde 409. Il grafo (PUT …/graph) non si modifica da telefono.
//

import Foundation

nonisolated enum AdminWorkflowsAPI {
    /// Il massimo che il server dà in una pagina.
    static let maxPageSize = 100

    private static func base(_ companyId: String) -> String { "v1/companies/\(companyId)/topologies" }

    // MARK: Flussi

    /// GET …/topologies, dal più recente. Senza `status` il server non filtra per stato.
    static func flows(companyId: String, status: String?, limit: Int, skip: Int) -> AriaEndpoint<AdminWorkflowPage> {
        var query = [URLQueryItem(name: "limit", value: "\(min(max(limit, 1), maxPageSize))"),
                     URLQueryItem(name: "skip", value: "\(max(skip, 0))")]
        if let status { query.append(URLQueryItem(name: "status", value: status)) }
        return AriaEndpoint(method: "GET", path: base(companyId), query: query)
    }

    static func flow(companyId: String, flowId: String) -> AriaEndpoint<AdminWorkflow> {
        .get("\(base(companyId))/\(flowId)")
    }

    static func create(companyId: String, _ body: AdminWorkflowCreate) -> AriaEndpoint<AdminWorkflow> {
        .post(base(companyId), body: body)
    }

    /// PATCH: solo nome e descrizione (il grafo non si tocca da qui).
    static func update(companyId: String, flowId: String,
                       _ body: AdminWorkflowMetadataUpdate) -> AriaEndpoint<AdminWorkflow> {
        .patch("\(base(companyId))/\(flowId)", body: body)
    }

    static func delete(companyId: String, flowId: String) -> AriaEndpoint<AriaNoContent> {
        .delete("\(base(companyId))/\(flowId)")
    }

    static func archive(companyId: String, flowId: String, revision: Int) -> AriaEndpoint<AdminWorkflow> {
        .post("\(base(companyId))/\(flowId)/archive", body: AdminWorkflowRevision(revision: revision))
    }

    static func unarchive(companyId: String, flowId: String, revision: Int) -> AriaEndpoint<AdminWorkflow> {
        .post("\(base(companyId))/\(flowId)/unarchive", body: AdminWorkflowRevision(revision: revision))
    }

    static func duplicate(companyId: String, flowId: String, name: String?) -> AriaEndpoint<AdminWorkflow> {
        .post("\(base(companyId))/\(flowId)/duplicate", body: AdminWorkflowDuplicate(name: name))
    }

    /// Risponde con la versione pubblicata, non col flusso: dopo si rilegge il flusso (revision e versione cambiano).
    static func publish(companyId: String, flowId: String, revision: Int) -> AriaEndpoint<AdminWorkflowVersion> {
        .post("\(base(companyId))/\(flowId)/publish", body: AdminWorkflowRevision(revision: revision))
    }

    /// Controlla il flusso salvato (errori e avvisi), senza cambiare niente.
    static func validate(companyId: String, flowId: String) -> AriaEndpoint<AdminWorkflowValidation> {
        .post("\(base(companyId))/\(flowId)/validate")
    }

    // MARK: Versioni

    static func versions(companyId: String, flowId: String) -> AriaEndpoint<AriaLossyArray<AdminWorkflowVersion>> {
        .get("\(base(companyId))/\(flowId)/versions")
    }

    /// Riporta il flusso al grafo di una versione pubblicata: risponde col flusso aggiornato.
    static func restore(companyId: String, flowId: String, version: Int, revision: Int) -> AriaEndpoint<AdminWorkflow> {
        .post("\(base(companyId))/\(flowId)/versions/\(version)/restore",
              body: AdminWorkflowRevision(revision: revision))
    }
}

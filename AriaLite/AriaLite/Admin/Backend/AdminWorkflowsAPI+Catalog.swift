//
//  AdminWorkflowsAPI+Catalog.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il catalogo della sezione Workflows: i modelli di flusso già pronti, i tipi di nodo e gli agenti.
//  Le rotte non hanno uno schema (oggetti liberi): le risposte si leggono in modo tollerante.
//

import Foundation

extension AdminWorkflowsAPI {
    /// GET /v1/topologies: i flussi di base da cui partire.
    static func templates() -> AriaEndpoint<AdminWorkflowTemplateList> {
        .get("v1/topologies")
    }

    /// GET /v1/topologies/{name}/graph: il grafo di un modello, per creare un flusso da lì.
    static func templateGraph(name: String) -> AriaEndpoint<AdminWorkflowTemplateGraph> {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return .get("v1/topologies/\(encoded)/graph")
    }

    /// GET /v1/topologies/node-kinds: i tipi di nodo e se sono disponibili su questo server.
    static func nodeKinds() -> AriaEndpoint<AriaLossyArray<AdminWorkflowNodeKindInfo>> {
        .get("v1/topologies/node-kinds")
    }
}

//
//  AdminKnowledgeGraphAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le liste da cui la pagina /knowledge-graph della web compone il grafo (asset e ricambi hanno già
//  le loro rotte in AdminAssetsAPI e AdminSparePartsAPI). Una riga per rotta, risposte in snake_case;
//  documenti ed elaborazioni arrivano già in camelCase, `.snakeCased()` li lascia come sono.
//

import Foundation

nonisolated enum AdminKnowledgeGraphAPI {
    /// GET /v1/alarms. Senza `status` il server dà solo gli `approved`: la conoscenza validata.
    static func alarms() -> AriaEndpoint<AriaLossyArray<AdminKnowledgeGraphAlarm>> {
        get("v1/alarms", [:])
    }

    /// GET /v1/maintenance-plans, anche qui solo gli `approved`.
    static func maintenancePlans() -> AriaEndpoint<AriaLossyArray<AdminKnowledgeGraphMaintenancePlan>> {
        get("v1/maintenance-plans", [:])
    }

    /// GET /v1/work-orders: aperti e chiusi, i più recenti (il server ne dà al massimo 200).
    static func workOrders(limit: Int = 200) -> AriaEndpoint<AriaLossyArray<AdminKnowledgeGraphWorkOrder>> {
        get("v1/work-orders", ["status_group": "all", "limit": "\(min(max(limit, 1), 200))"])
    }

    /// GET /v1/documents: `company_id` va anche in query (obbligatorio), pagine da massimo 100.
    static func documents(companyId: String, skip: Int, limit: Int = 100) -> AriaEndpoint<AdminKnowledgeGraphPage<AdminKnowledgeGraphDocument>> {
        get("v1/documents", ["company_id": companyId, "skip": "\(max(skip, 0))", "limit": "\(min(max(limit, 1), 100))"])
    }

    /// GET /v1/documents/{document_id}/runs: le elaborazioni più recenti del documento.
    static func documentRuns(documentId: String, limit: Int = 20) -> AriaEndpoint<AdminKnowledgeGraphPage<AdminKnowledgeGraphDocumentRun>> {
        get("v1/documents/\(documentId)/runs", ["limit": "\(min(max(limit, 1), 100))"])
    }

    /// GET con i soli parametri presenti (`AriaEndpoint.get` non salta i nil).
    private static func get<Response: Decodable & Sendable>(_ path: String, _ query: KeyValuePairs<String, String?>) -> AriaEndpoint<Response> {
        let items = query.compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } }
        return AriaEndpoint(method: "GET", path: path, query: items).snakeCased()
    }
}

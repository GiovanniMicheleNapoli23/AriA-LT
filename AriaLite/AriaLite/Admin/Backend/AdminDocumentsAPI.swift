//
//  AdminDocumentsAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte della libreria documenti (pagina /knowledge della web). Una riga per rotta, si eseguono con
//  `backend.api.call(endpoint)`. Diverso da Assets: questo servizio parla camelCase (`companyId`, `fileNames`),
//  quindi i body JSON NON passano da `.snakeCased()`; le risposte sì (convertFromSnakeCase lascia il camelCase com'è).
//

import Foundation

nonisolated enum AdminDocumentsAPI {
    /// Il massimo per pagina accettato dal server su liste, run e chunk.
    static let maxPage = 100

    // MARK: Documenti

    /// GET /v1/documents. `company_id` è obbligatorio come query, l'header non basta.
    static func documents(companyId: String, plantId: String?, state: String? = nil,
                          skip: Int, limit: Int) -> AriaEndpoint<AdminDocumentPage<AdminDocument>> {
        get("v1/documents", ["company_id": companyId, "plant_id": plantId, "state": state,
                             "skip": "\(max(skip, 0))", "limit": "\(clamp(limit))"])
    }

    static func document(id: String) -> AriaEndpoint<AdminDocument> {
        AriaEndpoint.get("v1/documents/\(id)").snakeCased()
    }

    /// 202: la cancellazione vera (vettori, S3, chunk) avviene dopo. `rollbackEntities` toglie anche
    /// le entità CMMS proposte dall'estrazione.
    static func delete(id: String, rollbackEntities: Bool) -> AriaEndpoint<AriaNoContent> {
        AriaEndpoint(method: "DELETE", path: "v1/documents/\(id)",
                     query: [URLQueryItem(name: "rollback_entities", value: rollbackEntities ? "true" : "false")])
    }

    // MARK: Pipeline

    /// Ferma tutte le run attive del documento.
    static func cancel(id: String) -> AriaEndpoint<AriaNoContent> {
        AriaEndpoint.post("v1/documents/\(id)/cancel")
    }

    /// Rilancia l'estrazione dei dati di manutenzione (CMMS). `language` è la lingua dei risultati.
    static func extract(id: String, language: String) -> AriaEndpoint<AriaNoContent> {
        AriaEndpoint(method: "POST", path: "v1/documents/\(id)/extract",
                     query: [URLQueryItem(name: "language", value: language)])
    }

    /// Rilancia l'indicizzazione (RAG). Body camelCase come da schema (IngestDocumentRequest).
    static func ingest(id: String, companyId: String) -> AriaEndpoint<AriaNoContent> {
        AriaEndpoint.post("v1/documents/\(id)/ingest", body: AdminDocumentIngestBody(companyId: companyId))
    }

    static func runs(id: String, skip: Int = 0, limit: Int = 20) -> AriaEndpoint<AdminDocumentPage<AdminDocumentRun>> {
        get("v1/documents/\(id)/runs", ["skip": "\(max(skip, 0))", "limit": "\(clamp(limit))"])
    }

    static func chunks(id: String, runId: String? = nil, skip: Int, limit: Int) -> AriaEndpoint<AdminDocumentPage<AdminDocumentChunk>> {
        get("v1/documents/\(id)/chunks", ["run_id": runId, "skip": "\(max(skip, 0))", "limit": "\(clamp(limit))"])
    }

    // MARK: Caricamento

    /// I nomi di file già presenti nello stabilimento. Risposta `{stringa: [stringhe]}` dal significato non
    /// documentato: si legge libera (vedi `AdminDocumentConflicts`). Niente `.snakeCased()`: le chiavi
    /// della risposta possono essere nomi di file, da non toccare.
    static func conflicts(companyId: String, plantId: String, fileNames: [String]) -> AriaEndpoint<AriaJSON> {
        AriaEndpoint.post("v1/documents/upload/conflicts",
                          body: AdminDocumentConflictBody(companyId: companyId, plantId: plantId, fileNames: fileNames))
    }

    // MARK: Utilità

    private static func clamp(_ limit: Int) -> Int { min(max(limit, 1), maxPage) }

    /// GET con i soli parametri presenti (`AriaEndpoint.get` non salta i nil).
    private static func get<Response: Decodable & Sendable>(_ path: String, _ query: KeyValuePairs<String, String?>) -> AriaEndpoint<Response> {
        let items = query.compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } }
        return AriaEndpoint(method: "GET", path: path, query: items).snakeCased()
    }
}

/// POST /v1/documents/{id}/ingest.
nonisolated struct AdminDocumentIngestBody: Encodable, Sendable {
    let companyId: String
    var triggeredBy = "user"
}

/// POST /v1/documents/upload/conflicts.
nonisolated struct AdminDocumentConflictBody: Encodable, Sendable {
    let companyId: String
    let plantId: String
    let fileNames: [String]
}

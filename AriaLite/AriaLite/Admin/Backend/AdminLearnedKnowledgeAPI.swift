//
//  AdminLearnedKnowledgeAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte della sezione Learned knowledge, come la pagina /settings/memory della web.
//  ATTENZIONE: i fatti imparati viaggiano in camelCase (`plantId`, `hitCount`, `createdAt`), quindi niente
//  `.snakeCased()`; i membri dell'azienda invece sono in snake_case (`full_name`) e lo vogliono.
//  La traduzione dei fatti non sta qui: è `AriaChatAPI.translateFacts` (lotti e limiti già gestiti).
//

import Foundation

nonisolated enum AdminLearnedKnowledgeAPI {
    /// Il massimo che il server dà in una pagina.
    static let maxPageSize = 200

    // MARK: Fatti

    /// GET …/memory-facts, dal più recente. Senza `status` il server non filtra per stato.
    static func facts(companyId: String, status: String?, limit: Int, offset: Int) -> AriaEndpoint<AdminMemoryFactPage> {
        var query = [URLQueryItem(name: "limit", value: "\(min(max(limit, 1), maxPageSize))"),
                     URLQueryItem(name: "offset", value: "\(max(offset, 0))")]
        if let status { query.append(URLQueryItem(name: "status", value: status)) }
        return AriaEndpoint(method: "GET", path: "v1/companies/\(companyId)/memory-facts", query: query)
    }

    /// Un fatto scritto a mano: entra già approvato. Se ne duplica uno esistente torna quello, rinforzato.
    static func create(companyId: String, _ body: AdminMemoryFactCreate) -> AriaEndpoint<AdminMemoryFact> {
        .post("v1/companies/\(companyId)/memory-facts", body: body)
    }

    /// PATCH = moderazione (approva o rifiuta, con eventuale ritocco del testo): cambia lo stato.
    static func moderate(companyId: String, factId: String, _ body: AdminMemoryFactModeration) -> AriaEndpoint<AdminMemoryFact> {
        .patch("v1/companies/\(companyId)/memory-facts/\(factId)", body: body)
    }

    /// PUT = modifica di testo, contesto e categoria: lo stato non cambia.
    static func update(companyId: String, factId: String, _ body: AdminMemoryFactUpdate) -> AriaEndpoint<AdminMemoryFact> {
        .put("v1/companies/\(companyId)/memory-facts/\(factId)", body: body)
    }

    static func delete(companyId: String, factId: String) -> AriaEndpoint<AriaNoContent> {
        .delete("v1/companies/\(companyId)/memory-facts/\(factId)")
    }

    // MARK: Membri

    /// Chi fa parte dell'azienda: serve a dare un nome a chi ha proposto o validato un fatto.
    static func members() -> AriaEndpoint<AriaLossyArray<AdminLearnedKnowledgeMember>> {
        AriaEndpoint.get("v1/members").snakeCased()
    }
}

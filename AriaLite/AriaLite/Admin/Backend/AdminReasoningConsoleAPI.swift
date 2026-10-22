//
//  AdminReasoningConsoleAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte della Reasoning console (pagine /settings/sessions della web): le trace dei turni dell'agente
//  e l'attribution di una risposta. Diversamente dalle altre rotte admin sono in camelCase (anche il
//  parametro `sessionId`): niente `.snakeCased()`. Storico, rinomina ed elimina sono già in AriaChatAPI.
//

import Foundation

nonisolated enum AdminReasoningConsoleAPI {
    /// Il massimo che il server accetta per pagina. La rotta non ha offset: si chiede tutto in una volta.
    static let maxTurns = 200

    /// GET …/turn-traces: i riassunti dei turni di UNA sessione, i più recenti per primi.
    static func turnTraces(companyId: String, sessionId: String,
                           limit: Int = maxTurns) -> AriaEndpoint<AdminReasoningTurnList> {
        AriaEndpoint(method: "GET", path: "v1/companies/\(companyId)/turn-traces",
                     query: [URLQueryItem(name: "sessionId", value: sessionId),
                             URLQueryItem(name: "limit", value: "\(min(max(limit, 1), maxTurns))")])
    }

    /// Il record completo di un turno. 404 `trace_not_found`: alcuni turni la trace non la scrivono mai.
    static func turnTrace(companyId: String, responseId: String) -> AriaEndpoint<AdminReasoningTrace> {
        AriaEndpoint.get("v1/companies/\(companyId)/turn-traces/\(responseId)")
    }

    /// A quale parte del prompt somiglia di più ogni frase della risposta. Si calcola al momento;
    /// 409 `attribution_unavailable` è definitivo (prompt o risposta non catturati, niente embedder).
    static func attribution(companyId: String, responseId: String) -> AriaEndpoint<AdminReasoningAttribution> {
        AriaEndpoint.get("v1/companies/\(companyId)/turn-traces/\(responseId)/attribution")
    }
}

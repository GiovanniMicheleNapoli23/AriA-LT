//
//  AdminScenarioAnalysisAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le rotte della sezione Scenario analysis (pagina /settings/scenario-analysis della web): scenari ricorrenti,
//  backfill, chiusure di procedura e revisione delle sessioni. Una riga per rotta, con `backend.api.call(endpoint)`.
//  A differenza di Assets queste rotte sono in camelCase sul filo: niente `.snakeCased()`.
//  Traduzione dei fatti e report .docx sono già in AriaChatAPI (`translateFacts`, `reportDocument`).
//

import Foundation

nonisolated enum AdminScenarioAnalysisAPI {
    private static func company(_ companyId: String) -> String { "v1/companies/\(companyId)" }

    // MARK: Scenari

    /// Ogni situazione ricorrente gestita da Aria, dalla più sostenuta. `kind`: `alarm` o `procedure`.
    static func scenarios(companyId: String, plantId: String?, kind: String?) -> AriaEndpoint<AdminScenarioListResponse> {
        get("\(company(companyId))/scenarios", ["plant_id": plantId, "kind": kind])
    }

    /// Ricava gli scenari dalle sessioni concluse, un lotto alla volta (si richiama finché `hasMore`).
    /// `force`: rigiudica anche quelle già valutate. Ripeterlo è sicuro: ogni sessione si conta una volta sola.
    static func backfill(companyId: String, limit: Int = 50, force: Bool) -> AriaEndpoint<AdminScenarioBackfillResult> {
        AriaEndpoint(method: "POST", path: "\(company(companyId))/scenarios/backfill", query: [
            URLQueryItem(name: "limit", value: "\(min(max(limit, 1), 200))"),
            URLQueryItem(name: "force", value: force ? "true" : "false"),
        ])
    }

    // MARK: Chiusure di procedura

    /// Le procedure chiuse senza riparazione confermata, dalle più recenti. Senza `status` le dà tutte.
    static func closures(companyId: String, status: String?, limit: Int) -> AriaEndpoint<AdminScenarioClosureList> {
        get("\(company(companyId))/procedure-closures", ["status": status, "limit": "\(min(max(limit, 1), 200))"])
    }

    // MARK: Revisione delle sessioni

    static func sessionReviews(companyId: String, plantId: String?, limit: Int) -> AriaEndpoint<AdminScenarioReviewList> {
        get("\(company(companyId))/session-reviews", ["plant_id": plantId, "limit": "\(min(max(limit, 1), 500))"])
    }

    /// Corregge il verdetto di UNA procedura della chat e rifà i conteggi. `episode` va sempre passato:
    /// senza, il server scrive sulla procedura in corso, non su quella a schermo.
    static func correctReview(companyId: String, sessionId: String, episode: Int,
                              _ body: AdminScenarioReviewRequest) -> AriaEndpoint<AdminScenarioSessionReview> {
        AriaEndpoint(method: "POST", path: "\(company(companyId))/session-reviews/\(sessionId)",
                     query: [URLQueryItem(name: "episode", value: "\(episode)")], body: body)
    }

    /// Aggiunge una nota dell'admin alla traccia della procedura (mai modificata: una seconda opinione è una seconda nota).
    static func addNote(companyId: String, sessionId: String, episode: Int,
                        note: String) -> AriaEndpoint<AdminScenarioFeedbackEvent> {
        AriaEndpoint(method: "POST", path: "\(company(companyId))/session-reviews/\(sessionId)/note",
                     query: [URLQueryItem(name: "episode", value: "\(episode)")], body: AdminScenarioNoteRequest(note: note))
    }

    /// GET con i soli parametri presenti (`AriaEndpoint.get` non salta i nil).
    private static func get<Response: Decodable & Sendable>(_ path: String, _ query: KeyValuePairs<String, String?>) -> AriaEndpoint<Response> {
        let items = query.compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } }
        return AriaEndpoint(method: "GET", path: path, query: items)
    }
}

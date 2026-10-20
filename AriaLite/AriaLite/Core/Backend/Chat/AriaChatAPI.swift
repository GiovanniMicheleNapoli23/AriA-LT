//
//  AriaChatAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 25/09/26.
//
//  Endpoint REST usati dalla chat oltre allo stream: storico sessioni, turni, checklist,
//  suggerimenti, feedback, memoria e closeout. Ogni rotta è un AriaEndpoint (vedi AriaEndpoint.swift).
//
//  Le rotte sono quelle condivise del backend (`/v1/mobile/*` non esiste più): storico, turni (riaggancio e
//  Stop), checklist, rinomina ed elimina stanno sotto /v1/agent/sessions; feedback, review e learning sotto
//  /v1/chat/sessions; il Real-time Learning sotto /v1/companies/{id}/memory-facts. Suggerimenti, conferma di
//  un fatto e closeout non sono tra le operazioni dell'operatore: per lui non si chiamano, così non si riceve
//  un 403 certo.
//

import Foundation

nonisolated struct AriaChatAPI: Sendable {
    let api: AriaAPIClient

    /// L'operatore (accesso col link): ha solo le operazioni da campo elencate nella guida.
    var isOperator: Bool { api.auth.isMobileSession }

    /// Storico, messaggi, turni e checklist di una sessione.
    private let history = "v1/agent/sessions"
    /// Feedback, review e learning di una sessione.
    private let feedback = "v1/chat/sessions"

    // MARK: Sessioni

    /// Una pagina di storico. Le sessioni `__briefing-*` sono interne e si nascondono.
    func sessions(limit: Int = 60, offset: Int = 0) async throws -> [AriaSessionSummary] {
        try await api.call(.get(history, query: ["limit": "\(limit)", "offset": "\(offset)"]))
    }

    func messages(sessionId: String) async throws -> [AriaPersistedMessage] {
        let rows: AriaLossyArray<AriaPersistedMessage> = try await api.call(.get("\(history)/\(sessionId)/messages"))
        return rows.items
    }

    /// `{"interrupt": null}` quando non c'è nessuna pausa; un 404 vuol dire solo sessione sconosciuta: mai un errore.
    func pendingInterrupt(sessionId: String) async -> AriaInterrupt? {
        let response: AriaPendingInterruptResponse? = try? await api.call(.get("\(history)/\(sessionId)/pending-interrupt"))
        return response?.interrupt
    }

    func rename(sessionId: String, title: String) async throws {
        try await api.perform("PATCH", "v1/agent/sessions/\(sessionId)", body: ["title": title])
    }

    func delete(sessionId: String) async throws {
        try await api.perform("DELETE", "v1/agent/sessions/\(sessionId)")
    }

    // MARK: Turni e checklist

    /// Spunte salvate e turno ancora aperto (`active_turn`: `running` o `paused`).
    func sessionState(sessionId: String) async throws -> AriaChatSessionState {
        try await api.call(.get("\(history)/\(sessionId)"))
    }

    /// Lo stato del turno: si interroga ogni ~2 s finché resta `running`.
    func turn(_ responseId: String, sessionId: String) async throws -> AriaTurn {
        try await api.call(.get("\(history)/\(sessionId)/turns/\(responseId)"))
    }

    /// Stop: chiudere lo stream di un turno in background non ferma la risposta. 202, poi si segue il turno finché non è più `running`.
    /// Un turno già finito (409 `turn_not_running`) non è un errore.
    func cancelTurn(_ responseId: String, sessionId: String) async throws {
        do {
            try await api.perform("POST", "\(history)/\(sessionId)/turns/\(responseId)/cancel")
        } catch AriaError.turnConflict(let conflict) where conflict.code == .turnNotRunning {
            return
        }
    }

    /// Sostituisce tutte le spunte della sessione: si mandano solo quelle spuntate (body sotto gli 8 KB).
    func saveChecklist(_ checked: some Sequence<String>, sessionId: String) async throws {
        try await api.perform("PUT", "\(history)/\(sessionId)/checklist", body: AriaChecklist(checked: checked))
    }

    // MARK: Suggerimenti

    func suggestions(plantId: String, locale: String) async -> [String] {
        if isOperator { return [] }
        let response: AriaSuggestionsResponse? = try? await api.call(.get("v1/chat/suggestions",
                                                                          query: ["plant_id": plantId, "locale": locale]))
        return response?.suggestions ?? []
    }

    // MARK: Feedback

    private nonisolated struct AnswerFeedback: Encodable, Sendable {
        let vote: String
        let messageId: String
        let note: String?
        let answer: String?
        let question: String?
    }

    /// Pollice su/giù. Ripetere lo stesso voto lo ritira: decide il campo `vote` della risposta.
    func answerFeedback(sessionId: String, vote: String, messageId: String, note: String?,
                        answer: String?, question: String?) async throws -> AriaAnswerFeedbackResponse {
        try await api.call(.post("\(feedback)/\(sessionId)/feedback/answer",
                                 body: AnswerFeedback(vote: vote, messageId: messageId, note: note, answer: answer, question: question)))
    }

    private nonisolated struct StepFeedback: Encodable, Sendable {
        let action: String
        let step: Int
        let task: String
        let stepKind: String
        let stepTitle: String
        let stepLabel: String
    }

    /// Segnale su un task di procedura: failed | unclear | modify | custom.
    func stepFeedback(sessionId: String, action: String, taskList: AriaTaskList, task: String) async {
        let body = StepFeedback(action: action, step: taskList.stepNumber, task: task,
                                stepKind: taskList.isSafety ? "safety" : "technical",
                                stepTitle: taskList.stepTitle, stepLabel: taskList.label)
        try? await api.perform("POST", "\(feedback)/\(sessionId)/feedback/step", body: body)
    }

    private nonisolated struct Review: Encodable, Sendable {
        let outcome: String
        let rating: Int?
        let issues: String?
    }

    func review(sessionId: String, outcome: String, rating: Int?, issues: String?) async throws {
        try await api.perform("POST", "\(feedback)/\(sessionId)/review",
                              body: Review(outcome: outcome, rating: rating, issues: issues))
    }

    private nonisolated struct LearningAnswer: Encodable, Sendable {
        let key: String?
        let value: String?
        let text: String
        let custom: String
    }

    func learning(sessionId: String, answers: [AriaElicitationAnswer]) async {
        let body = ["answers": answers.map { LearningAnswer(key: $0.key, value: $0.value, text: $0.text, custom: $0.custom) }]
        try? await api.perform("POST", "\(feedback)/\(sessionId)/learning", body: body)
    }

    // MARK: Memoria

    private nonisolated struct Validation: Encodable, Sendable {
        let question: String
        let answer: String
        let feedback: String
        let plantId: String
        let sessionId: String?
    }

    /// Risposta al Real-time Learning: diventa conoscenza dello stabilimento (fatti PENDING), mai un turno di chat.
    /// `plantId` è obbligatorio, e se la sessione ha già uno stabilimento deve essere lo stesso (422).
    /// I campi si tagliano ai limiti del server (buildValidationBody della web): meglio corto che un 422.
    func submitValidation(companyId: String, plantId: String, sessionId: String, question: String,
                          answer: String, feedback: String) async throws -> AriaMemoryValidationResponse {
        let body = Validation(question: String(question.prefix(4000)), answer: String(answer.prefix(8000)),
                              feedback: String(feedback.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000)),
                              plantId: plantId, sessionId: sessionId)
        return try await api.call(.post("v1/companies/\(companyId)/memory-facts/validation", body: body))
    }

    /// Tieni / scarta un fatto che Aria propone di imparare.
    func confirmMemory(companyId: String, factId: String, accept: Bool) async throws {
        if isOperator { throw AriaError.notOnPhone }
        try await api.perform("POST", "v1/companies/\(companyId)/memory-facts/\(factId)/confirm",
                              body: ["decision": accept ? "accept" : "reject"])
    }

    // MARK: Closeout

    /// Senza `confirm` restituisce solo la proposta; con `confirm: true` scrive in ARIA (e MaintainX).
    func closeout(companyId: String, sessionId: String, _ request: AriaCloseoutRequest) async throws -> AriaCloseoutResult {
        if isOperator { throw AriaError.notOnPhone }
        return try await api.call(.post("v1/companies/\(companyId)/sessions/\(sessionId)/closeout", body: request))
    }
}

/// Una risposta a un passo di domanda guidata (ElicitationAnswer della web).
nonisolated struct AriaElicitationAnswer: Sendable, Hashable {
    var key: String?
    var value: String?
    var text: String
    var custom: String
    var file: String?
}

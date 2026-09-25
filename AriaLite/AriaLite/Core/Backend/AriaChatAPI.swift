//
//  AriaChatAPI.swift
//  AriaLite
//
//  Endpoint REST usati dalla chat oltre allo stream: storico sessioni,
//  suggerimenti, feedback, memoria e closeout. Stessi path della web.
//

import Foundation

nonisolated struct AriaChatAPI: Sendable {
    let api: AriaAPIClient

    // MARK: Sessioni

    /// Una pagina di storico. Le sessioni `__briefing-*` sono interne e si nascondono.
    func sessions(limit: Int = 60, offset: Int = 0) async throws -> [AriaSessionSummary] {
        let page: [AriaSessionSummary] = try await api.get("v1/agent/sessions", query: [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ])
        return page
    }

    func messages(sessionId: String) async throws -> [AriaPersistedMessage] {
        let rows: AriaLossyArray<AriaPersistedMessage> = try await api.get("v1/agent/sessions/\(sessionId)/messages")
        return rows.items
    }

    func pendingInterrupt(sessionId: String) async -> AriaInterrupt? {
        let response: AriaPendingInterruptResponse? = try? await api.get("v1/agent/sessions/\(sessionId)/pending-interrupt")
        return response?.interrupt
    }

    func rename(sessionId: String, title: String) async throws {
        try await api.perform("PATCH", "v1/agent/sessions/\(sessionId)", body: ["title": title])
    }

    func delete(sessionId: String) async throws {
        try await api.perform("DELETE", "v1/agent/sessions/\(sessionId)")
    }

    // MARK: Suggerimenti

    func suggestions(plantId: String, locale: String) async -> [String] {
        let response: AriaSuggestionsResponse? = try? await api.get("v1/chat/suggestions", query: [
            URLQueryItem(name: "plant_id", value: plantId),
            URLQueryItem(name: "locale", value: locale),
        ])
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
        try await api.send("POST", "v1/chat/sessions/\(sessionId)/feedback/answer",
                           body: AnswerFeedback(vote: vote, messageId: messageId, note: note, answer: answer, question: question))
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
        try? await api.perform("POST", "v1/chat/sessions/\(sessionId)/feedback/step", body: body)
    }

    private nonisolated struct Review: Encodable, Sendable {
        let outcome: String
        let rating: Int?
        let issues: String?
    }

    func review(sessionId: String, outcome: String, rating: Int?, issues: String?) async throws {
        try await api.perform("POST", "v1/chat/sessions/\(sessionId)/review",
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
        try? await api.perform("POST", "v1/chat/sessions/\(sessionId)/learning", body: body)
    }

    // MARK: Memoria

    /// Tieni / scarta un fatto che Aria propone di imparare.
    func confirmMemory(companyId: String, factId: String, accept: Bool) async throws {
        try await api.perform("POST", "v1/companies/\(companyId)/memory-facts/\(factId)/confirm",
                              body: ["decision": accept ? "accept" : "reject"])
    }

    // MARK: Closeout

    /// Senza `confirm` restituisce solo la proposta; con `confirm: true` scrive in ARIA (e MaintainX).
    func closeout(companyId: String, sessionId: String, _ request: AriaCloseoutRequest) async throws -> AriaCloseoutResult {
        try await api.send("POST", "v1/companies/\(companyId)/sessions/\(sessionId)/closeout", body: request)
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

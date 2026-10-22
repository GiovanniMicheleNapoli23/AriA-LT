//
//  AdminLLMUsageAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Rotte del consumo AI per la pagina /settings/usage della web: riepilogo del periodo, listino prezzi,
//  sessioni con i loro totali e Stop di una sessione attiva. Le date del periodo viaggiano in ISO 8601.
//  Body e risposte in snake_case (`.snakeCased()`), i modelli restano in camelCase.
//

import Foundation

nonisolated struct AdminLLMUsageAPI: Sendable {
    let api: AriaAPIClient

    private let usage = "v1/usage"
    private let chatSessions = "v1/chat/sessions"

    /// GET /v1/usage/summary?from=&to=: totali, giorno per giorno e per modello del periodo.
    func summary(from: Date, to: Date) async throws -> AdminLLMUsageSummary {
        let query: KeyValuePairs<String, String> = [
            "from": from.formatted(.iso8601),
            "to": to.formatted(.iso8601),
        ]
        return try await api.call(AriaEndpoint<AdminLLMUsageSummary>.get("\(usage)/summary", query: query).snakeCased())
    }

    /// GET /v1/usage/pricing: il listino per modello, in euro per milione di token.
    func pricing() async throws -> AdminLLMUsagePricing {
        try await api.call(AriaEndpoint<AdminLLMUsagePricing>.get("\(usage)/pricing").snakeCased())
    }

    /// GET /v1/chat/sessions: le sessioni più recenti, con i loro totali. Una riga illeggibile si salta.
    func sessions(limit: Int = 20) async throws -> [AdminLLMUsageSession] {
        let endpoint: AriaEndpoint<AriaLossyArray<AdminLLMUsageSession>> =
            AriaEndpoint.get(chatSessions, query: ["limit": "\(limit)"]).snakeCased()
        return try await api.call(endpoint).items
    }

    /// POST /v1/chat/sessions/{id}/stop: ferma una sessione attiva e restituisce la sua scheda aggiornata.
    func stop(sessionId: String) async throws -> AdminLLMUsageSession {
        try await api.call(AriaEndpoint<AdminLLMUsageSession>.post("\(chatSessions)/\(sessionId)/stop").snakeCased())
    }
}

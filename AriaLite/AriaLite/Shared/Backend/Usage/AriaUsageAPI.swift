//
//  AriaUsageAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le rotte dei crediti e della sezione Usage. Aperte a ogni membro: configurazione, stima di una risposta, saldo,
//  cruscotto e scheda del tetto di spesa. Solo per i titolari: salvataggio del tetto, storico, destinatari e regole
//  degli avvisi. Config, saldo e cruscotto rispondono 503 quando le cifre non si leggono: niente numeri e un
//  "Riprova", mai cifre tenute nell'app. I rifiuti con un codice (tetto, avvisi) arrivano come `AriaError.usageRefused`.
//

import Foundation

nonisolated struct AriaUsageAPI: Sendable {
    let api: AriaAPIClient

    /// GET /v1/usage/config: piano, livelli di impegno, peso delle azioni.
    func config() async throws -> AriaUsageConfig {
        try await api.call(.get("v1/usage/config"))
    }

    /// POST /v1/usage/estimate: il costo di una risposta di chat a questo livello (gratis, 60 s di cache a chi chiama).
    func estimate(_ level: AriaEffortLevel) async throws -> AriaUsageEstimate {
        try await api.call(.post("v1/usage/estimate", body: AriaUsageEstimateRequest(effort: level)))
    }

    /// GET /v1/usage/allowance: il saldo adesso.
    func allowance() async throws -> AriaAllowance {
        try await api.call(.get("v1/usage/allowance"))
    }

    // MARK: Cruscotto

    /// GET /v1/usage/dashboard: un ciclo. Senza date, quello corrente; con `from` e `to` (`YYYY-MM-DD`, primo e ultimo
    /// giorno di uno dei `cycles` della risposta) un ciclo passato. Un intervallo che attraversa cicli, rovesciato o
    /// nel futuro è un 422.
    func dashboard(from: String? = nil, to: String? = nil) async throws -> AriaUsageDashboard {
        var query: [URLQueryItem] = []
        if let from { query.append(URLQueryItem(name: "from", value: from)) }
        if let to { query.append(URLQueryItem(name: "to", value: to)) }
        var endpoint: AriaEndpoint<AriaUsageDashboard> = .get("v1/usage/dashboard")
        endpoint.query = query
        return try await api.call(endpoint)
    }

    // MARK: Tetto di spesa

    /// GET /v1/usage/spend-cap: ogni membro lo legge, i titolari per intero.
    func spendCap() async throws -> AriaSpendCapView {
        try await api.call(.get("v1/usage/spend-cap"))
    }

    /// PUT /v1/usage/spend-cap: salva il tetto o, con `nil`, lo toglie. La risposta è la scheda aggiornata. Rifiuti:
    /// `spend_cap_locked_trial`, `spend_cap_locked_unassigned`, `spend_cap_required`, `spend_cap_below_minimum`.
    func saveSpendCap(_ amount: Decimal?) async throws -> AriaSpendCapView {
        try await api.call(.put("v1/usage/spend-cap", body: AriaSpendCapRequest(amount: amount)))
    }

    /// GET /v1/usage/spend-cap/history: ogni modifica, la più recente per prima. Una riga illeggibile si scarta.
    func spendCapHistory() async throws -> [AriaSpendCapChange] {
        let rows: [AriaLenient<AriaSpendCapChange>] = try await api.call(.get("v1/usage/spend-cap/history"))
        return rows.compactMap(\.value)
    }

    // MARK: Avvisi

    /// GET /v1/usage/notice-recipients: i membri attivi e chi, oltre ai titolari, riceve gli avvisi.
    func noticeRecipients() async throws -> AriaNoticeRecipients {
        try await api.call(.get("v1/usage/notice-recipients"))
    }

    /// PUT /v1/usage/notice-recipients: sostituisce la lista degli aggiunti (vuota: nessuno). 422
    /// `recipient_not_active_member` con `userIds` quando una persona non è più un membro attivo; non si salva niente.
    func saveNoticeRecipients(_ userIds: [String]) async throws -> AriaNoticeRecipients {
        try await api.call(.put("v1/usage/notice-recipients", body: AriaNoticeRecipientsRequest(userIds: userIds)))
    }

    /// GET /v1/usage/notice-settings: le regole dei tre avvisi.
    func noticeSettings() async throws -> AriaNoticeSettings {
        try await api.call(.get("v1/usage/notice-settings"))
    }

    /// PUT /v1/usage/notice-settings: sostituisce TUTTE le sostituzioni dell'azienda. Il body si costruisce con
    /// `AriaNoticeSettings.payload(applying:to:)`. La risposta è la vista aggiornata. Si manda una richiesta alla volta.
    func saveNoticeSettings(_ overrides: AriaNoticeOverrides) async throws -> AriaNoticeSettings {
        try await api.call(.put("v1/usage/notice-settings", body: overrides))
    }
}

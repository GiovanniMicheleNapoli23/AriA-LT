//
//  AriaUsageDashboard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  GET /v1/usage/dashboard: un ciclo di crediti dell'azienda (cifre, serie giornaliera, ripartizioni). Ogni cifra viene
//  dal server; un importo `null` è nascosto, mai 0. Lettura tollerante: un campo illeggibile vale `nil`, una riga
//  illeggibile di un elenco si scarta senza far fallire il payload. I giorni (`YYYY-MM-DD`) restano stringhe UTC.
//

import Foundation

nonisolated struct AriaUsageDashboard: Decodable, Sendable, Equatable {
    /// Il tetto come lo legge ogni membro (`spend_cap`). `billed`, `billed_credits` e `percent` sono `nil` per chi non
    /// vede i soldi.
    nonisolated struct SpendCap: Decodable, Sendable, Equatable {
        var amount: Decimal?
        var creditsEquivalent: Decimal?
        var billed: Decimal?
        var billedCredits: Decimal?
        /// Intero, arrotondato per difetto.
        var percent: Int?
        var status: AriaSpendCapStatus?

        private enum CodingKeys: String, CodingKey {
            case amount, billed, percent, status
            case creditsEquivalent = "credits_equivalent", billedCredits = "billed_credits"
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            amount = c.ariaDecimal(.amount)
            creditsEquivalent = c.ariaDecimal(.creditsEquivalent)
            billed = c.ariaDecimal(.billed)
            billedCredits = c.ariaDecimal(.billedCredits)
            percent = c.ariaWhole(.percent)
            status = c.ariaLenient(String.self, .status).flatMap(AriaSpendCapStatus.init(rawValue:))
        }
    }

    /// Un giorno UTC del grafico. `credits` è quanto è stato addebitato, `tokenEquivalent` lo stesso giorno contato a
    /// dimensione (sono crediti, non token), `consumed` quanto ha pesato sul piano.
    nonisolated struct SeriesPoint: Decodable, Sendable, Equatable {
        /// `YYYY-MM-DD`, UTC. Senza giorno il punto si scarta.
        var day: String
        var credits: Decimal?
        var tokenEquivalent: Decimal?
        var consumed: Decimal?
        /// `false`: il giorno è fuori dal periodo (nella prova). Mancante vale `true`.
        var inPeriod = true

        private enum CodingKeys: String, CodingKey {
            case day, credits, consumed
            case tokenEquivalent = "token_equivalent", inPeriod = "in_period"
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            day = try c.decode(String.self, forKey: .day)
            credits = c.ariaDecimal(.credits)
            tokenEquivalent = c.ariaDecimal(.tokenEquivalent)
            consumed = c.ariaDecimal(.consumed)
            inPeriod = c.ariaLenient(.inPeriod) ?? true
        }
    }

    /// Una riga di ripartizione (per azione, persona o agente).
    nonisolated struct Row: Decodable, Sendable, Equatable {
        /// L'azione (`chat.reply`), l'id della persona, `agent:general` o `workflow:<id>`; `nil` = "Not attributed".
        var key: String?
        /// Solo una riga `workflow:` ha il nome del workflow.
        var label: String?
        var credits: Decimal?
        /// Un conteggio.
        var actions: Int?
        /// Quota dei crediti addebitati nel periodo; `nil` quando non è stato addebitato niente.
        var share: Decimal?

        private enum CodingKeys: String, CodingKey { case key, label, credits, actions, share }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            key = c.ariaLenient(.key)
            label = c.ariaLenient(.label)
            credits = c.ariaDecimal(.credits)
            actions = c.ariaWhole(.actions)
            share = c.ariaDecimal(.share)
        }
    }

    /// Un ciclo del selettore: primo e ultimo giorno, UTC, estremi compresi.
    nonisolated struct Cycle: Decodable, Sendable, Equatable {
        var start: String
        var end: String
    }

    /// `false` finché i clienti non possono vedere i consumi: ogni altro campo è vuoto.
    var enabled = false
    var tier: String?
    var tierSource: String?
    var currency: String?
    var amountsVisible = false
    var mode: AriaAllowanceMode?
    /// `nil` quando manca o non si conosce: si tratta come "ok".
    var state: AriaAllowanceState?
    /// Gli stessi campi del `period` del saldo.
    var period: AriaAllowance.Period?
    /// I crediti di oggi (`today.credits`); `nil` su un ciclo chiuso.
    var todayCredits: Decimal?
    /// Questa settimana (lunedì-domenica UTC); `nil` su un ciclo chiuso, su un pool e su un server vecchio.
    var week: AriaAllowance.Meter?
    /// `nil` dove nessun tetto vale (nessun tetto, prova, nessun piano) e su un server vecchio.
    var spendCap: SpendCap?
    /// Un elemento per giorno UTC finora, il più vecchio per primo.
    var series: [SeriesPoint] = []
    var byActionType: [Row] = []
    /// Un titolare li ha tutti, gli altri solo la propria riga.
    var byUser: [Row]?
    /// `nil` per chi non è titolare (diverso da `[]`: nessun agente ha lavorato).
    var byAgent: [Row]?
    var projection: AriaUsageProjection?
    var noticeThresholds: [Decimal] = []
    var trial: AriaUsageTrial?
    var billedUsers: Int?
    /// Crediti al giorno per utente del piano.
    var perUserCredits: Decimal?
    /// I cicli del selettore, dal più recente.
    var cycles: [Cycle] = []

    private enum CodingKeys: String, CodingKey {
        case enabled, tier, currency, mode, state, period, today, week, series, projection, trial, cycles
        case tierSource = "tier_source", amountsVisible = "amounts_visible", spendCap = "spend_cap"
        case byActionType = "by_action_type", byUser = "by_user", byAgent = "by_agent"
        case noticeThresholds = "notice_thresholds", billedUsers = "billed_users", perUserCredits = "per_user_credits"
    }

    private enum TodayKeys: String, CodingKey { case credits }

    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = c.ariaLenient(.enabled) ?? false
        tier = c.ariaLenient(.tier)
        tierSource = c.ariaLenient(.tierSource)
        currency = c.ariaLenient(.currency)
        amountsVisible = c.ariaLenient(.amountsVisible) ?? false
        mode = c.ariaLenient(String.self, .mode).flatMap(AriaAllowanceMode.init(rawValue:))
        state = c.ariaLenient(String.self, .state).flatMap(AriaAllowanceState.init(rawValue:))
        period = c.ariaLenient(.period)
        if let today = try? c.nestedContainer(keyedBy: TodayKeys.self, forKey: .today) {
            todayCredits = today.ariaDecimal(.credits)
        }
        week = c.ariaLenient(.week)
        spendCap = c.ariaLenient(.spendCap)
        series = Self.list(c, .series) ?? []
        byActionType = Self.list(c, .byActionType) ?? []
        byUser = Self.list(c, .byUser)
        byAgent = Self.list(c, .byAgent)
        projection = c.ariaLenient(.projection)
        noticeThresholds = (c.ariaLenient([AriaWireDecimal].self, .noticeThresholds) ?? []).compactMap(\.value)
        trial = c.ariaLenient(.trial)
        billedUsers = c.ariaWhole(.billedUsers)
        perUserCredits = c.ariaDecimal(.perUserCredits)
        cycles = Self.list(c, .cycles) ?? []
    }

    /// Un elenco i cui elementi illeggibili si scartano uno a uno; `nil` se la chiave manca, è `null` o non è un array.
    private static func list<Element: Decodable & Sendable>(
        _ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
    ) -> [Element]? {
        container.ariaLenient([AriaLenient<Element>].self, key)?.compactMap(\.value)
    }
}

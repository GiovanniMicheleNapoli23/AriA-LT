//
//  AriaAllowance.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  GET /v1/usage/allowance: il saldo dei crediti adesso. Lo stato (`ok`, `notice`, `pacing`, `overage`, `capped`) lo
//  decide il server: l'app non lo deduce da una percentuale e non calcola il saldo. Un importo `null` è nascosto,
//  mai "0". Lettura tollerante: ogni campo si decodifica da solo.
//

import Foundation

nonisolated enum AriaAllowanceState: String, Sendable, Equatable {
    case ok, notice, pacing, overage, capped
}

nonisolated struct AriaAllowance: Decodable, Sendable, Equatable {
    /// La finestra mobile (24 h) di un piano a crediti giornalieri; `nil` su un pool.
    nonisolated struct Window: Decodable, Sendable, Equatable {
        var hours: Int?
        /// Il totale dell'azienda: su un piano per utente è già moltiplicato per gli utenti fatturati.
        var dailyAllowance: Decimal?
        var consumed: Decimal?
        var available: Decimal?
        /// `nil` quando nell'ultima finestra non è stato usato niente.
        var nextRefillAt: Date?
        var billedUsers: Int?
        var perUserCredits: Decimal?

        private enum CodingKeys: String, CodingKey {
            case hours, consumed, available
            case dailyAllowance = "daily_allowance", nextRefillAt = "next_refill_at"
            case billedUsers = "billed_users", perUserCredits = "per_user_credits"
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            hours = c.ariaWhole(.hours)
            dailyAllowance = c.ariaDecimal(.dailyAllowance)
            consumed = c.ariaDecimal(.consumed)
            available = c.ariaDecimal(.available)
            nextRefillAt = AriaDate.parse(c.ariaLenient(String.self, .nextRefillAt))
            billedUsers = c.ariaWhole(.billedUsers)
            perUserCredits = c.ariaDecimal(.perUserCredits)
        }
    }

    /// Il ciclo (o il giorno UTC, in `mode == "day"`).
    nonisolated struct Period: Decodable, Sendable, Equatable {
        /// "cycle" o "day".
        var mode: String?
        /// Primo e ultimo giorno del ciclo, in UTC (`YYYY-MM-DD`): mai spostati nel fuso locale.
        var start: String?
        var end: String?
        /// Un ciclo chiuso è definitivo: niente oggi, proiezione, contatori né controlli. Mancante vale `false`.
        var closed = false
        /// "max", "credits" o "tokens".
        var basis: String?
        /// 0 o `nil`: il piano non dichiara una quota.
        var included: Decimal?
        var creditsUsed: Decimal?
        var tokenEquivalent: Decimal?
        var consumed: Decimal?
        /// I giorni inclusi nel periodo (30 in un ciclo di novembre).
        var includedDays: Int?
        /// La quota usata (può superare 1).
        var pct: Decimal?
        var overageCredits: Decimal?
        var overageAmount: Decimal?
        var pricePerCredit: Decimal?
        var extraCreditsBillable: Bool?
        var resetsAt: Date?
        var todayIncluded: Decimal?
        var todayConsumed: Decimal?
        var todayOverageCredits: Decimal?
        var todayOverageAmount: Decimal?
        /// Le chiavi (nomi del JSON) di cifre che il server ha mandato ma non si leggono: `included`, `consumed`, `pct`,
        /// `today_included`, `today_consumed`. Un valore `null` o assente non c'entra: quello è "assente".
        var unreadable: Set<String> = []

        private enum CodingKeys: String, CodingKey {
            case mode, start, end, closed, basis, included, consumed, pct
            case creditsUsed = "credits_used", tokenEquivalent = "token_equivalent", includedDays = "included_days"
            case overageCredits = "overage_credits", overageAmount = "overage_amount"
            case pricePerCredit = "price_per_credit", extraCreditsBillable = "extra_credits_billable"
            case resetsAt = "resets_at", todayIncluded = "today_included", todayConsumed = "today_consumed"
            case todayOverageCredits = "today_overage_credits", todayOverageAmount = "today_overage_amount"
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            mode = c.ariaLenient(.mode)
            start = c.ariaLenient(.start)
            end = c.ariaLenient(.end)
            closed = c.ariaLenient(.closed) ?? false
            basis = c.ariaLenient(.basis)
            included = c.ariaDecimal(.included)
            includedDays = c.ariaWhole(.includedDays)
            creditsUsed = c.ariaDecimal(.creditsUsed)
            tokenEquivalent = c.ariaDecimal(.tokenEquivalent)
            consumed = c.ariaDecimal(.consumed)
            pct = c.ariaDecimal(.pct)
            overageCredits = c.ariaDecimal(.overageCredits)
            overageAmount = c.ariaDecimal(.overageAmount)
            pricePerCredit = c.ariaDecimal(.pricePerCredit)
            extraCreditsBillable = c.ariaLenient(.extraCreditsBillable)
            resetsAt = AriaDate.parse(c.ariaLenient(String.self, .resetsAt))
            todayIncluded = c.ariaDecimal(.todayIncluded)
            todayConsumed = c.ariaDecimal(.todayConsumed)
            todayOverageCredits = c.ariaDecimal(.todayOverageCredits)
            todayOverageAmount = c.ariaDecimal(.todayOverageAmount)
            for key in [CodingKeys.included, .consumed, .pct, .todayIncluded, .todayConsumed] where c.ariaIsMalformedDecimal(key) {
                unreadable.insert(key.stringValue)
            }
        }
    }

    /// Un contatore ("Today", "This week"): usato, incluso, percentuale intera NON limitata a 100.
    nonisolated struct Meter: Decodable, Sendable, Equatable {
        var used: Decimal?
        var included: Decimal?
        var percent: Int?
        var resetsAt: Date?
        /// Da questa quota il contatore diventa ambra; `nil`: mai.
        var warnThreshold: Decimal?

        private enum CodingKeys: String, CodingKey {
            case used, included, percent
            case resetsAt = "resets_at", warnThreshold = "warn_threshold"
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            used = c.ariaDecimal(.used)
            included = c.ariaDecimal(.included)
            percent = c.ariaWhole(.percent)
            resetsAt = AriaDate.parse(c.ariaLenient(String.self, .resetsAt))
            warnThreshold = c.ariaDecimal(.warnThreshold)
        }
    }

    nonisolated struct Meters: Decodable, Sendable, Equatable {
        var today: Meter?
        var week: Meter?

        private enum CodingKeys: String, CodingKey { case today, week }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            today = c.ariaLenient(.today)
            week = c.ariaLenient(.week)
        }
    }

    /// Un giorno UTC del grafico dei 7 giorni.
    nonisolated struct Day: Decodable, Sendable, Equatable {
        /// `YYYY-MM-DD`, UTC.
        var day: String
        var credits: Decimal?

        private enum CodingKeys: String, CodingKey { case day, credits }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            day = try c.decode(String.self, forKey: .day)
            credits = c.ariaDecimal(.credits)
        }
    }

    var enabled = false
    var tier: String?
    var tierSource: String?
    var currency: String?
    var amountsVisible = false
    /// `nil` quando manca o non si conosce: si tratta come "ok".
    var state: AriaAllowanceState?
    var window: Window?
    var period: Period?
    var meters: Meters?
    /// I crediti di oggi (giorno UTC), da `today.credits`: servono nel modo "day".
    var todayCredits: Decimal?
    /// Sempre 7 giorni, il più vecchio per primo.
    var lastDays: [Day] = []
    /// Le quote a cui il cliente viene avvisato; la più bassa sotto 1 è la tacca sulle barre.
    var noticeThresholds: [Decimal] = []
    var trial: AriaUsageTrial?
    /// `daily` o `pool`; `nil` se manca o non si conosce.
    var mode: AriaAllowanceMode?
    /// Per i ruoli che vedono i soldi; `nil` per gli altri.
    var spendCap: AriaAllowanceSpendCap?
    /// L'archivio della conoscenza; `nil` quando il contatore non si legge (o su un server vecchio).
    var storage: AriaUsageStorage?
    /// Dove va il ciclo; `nil` su un ciclo chiuso, in modo "day" e prima del primo giorno completo.
    var projection: AriaUsageProjection?
    /// I minuti di Live Talk del ciclo; `nil` se il piano non li ha.
    var liveTalk: AriaUsageLiveTalk?

    private enum CodingKeys: String, CodingKey {
        case enabled, tier, currency, state, window, period, meters, today, trial, mode, storage, projection
        case tierSource = "tier_source", amountsVisible = "amounts_visible"
        case lastDays = "last_days", noticeThresholds = "notice_thresholds", spendCap = "spend_cap", liveTalk = "live_talk"
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
        state = c.ariaLenient(String.self, .state).flatMap(AriaAllowanceState.init(rawValue:))
        mode = c.ariaLenient(String.self, .mode).flatMap(AriaAllowanceMode.init(rawValue:))
        window = c.ariaLenient(.window)
        period = c.ariaLenient(.period)
        meters = c.ariaLenient(.meters)
        if let today = try? c.nestedContainer(keyedBy: TodayKeys.self, forKey: .today) {
            todayCredits = today.ariaDecimal(.credits)
        }
        lastDays = (c.ariaLenient([AriaLenient<Day>].self, .lastDays) ?? []).compactMap(\.value)
        noticeThresholds = (c.ariaLenient([AriaWireDecimal].self, .noticeThresholds) ?? []).compactMap(\.value)
        trial = c.ariaLenient(.trial)
        spendCap = c.ariaLenient(.spendCap)
        storage = c.ariaLenient(.storage)
        projection = c.ariaLenient(.projection)
        liveTalk = c.ariaLenient(.liveTalk)
    }

    /// Il tetto di spesa in valuta (`spend_cap.amount`); `nil` senza tetto o per chi non vede i soldi.
    var spendCapAmount: Decimal? { spendCap?.amount }
}

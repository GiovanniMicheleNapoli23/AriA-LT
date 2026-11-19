//
//  AdminUsageFacts.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I fatti che ogni riquadro della pagina Usage legge dal cruscotto, dalla config e dal saldo (`dashboard-model.ts`
//  della web): chi vede i soldi, che modo è, quale piano, cosa è noto. Puro: nessuna cifra nuova, solo lettura. Una
//  cifra che il server non ha mandato resta `nil` e il riquadro tralascia la frase che la direbbe.
//

import Foundation

/// Le parole dello stop al tetto: del giorno (piano a crediti giornalieri) o del ciclo (pool).
nonisolated enum AdminUsageStopPeriod: Sendable, Equatable {
    case day, cycle
}

nonisolated struct AdminUsageFacts: Sendable {
    let dashboard: AriaUsageDashboard
    let config: AriaUsageConfig
    /// Il saldo adesso; `nil` mentre si carica o se è fallito.
    let allowance: AriaAllowance?
    let period: AriaAllowance.Period
    /// Primo e ultimo giorno del ciclo, UTC.
    let start: String
    let end: String
    let locale: Locale

    /// Un titolare (`config.can_manage_plan`): l'unico segnale per le parti da titolare (regola 6).
    let owner: Bool
    let closed: Bool
    let dayMode: Bool
    /// La prova in corso sul ciclo corrente; `nil` su un ciclo chiuso.
    let trial: AriaUsageTrial?
    /// Nessun piano assegnato: cifre di Basic, niente addebiti, niente euro.
    let noPlan: Bool
    let pool: Bool
    /// Il chiamante vede gli euro e il server li ha mandati (mai senza piano).
    let seesMoney: Bool
    /// Un titolare che vede gli euro: le frasi con gli euro.
    let textOwner: Bool
    let currency: String
    let included: Decimal
    /// La quota del periodo come percentuale intera (73); 0 se manca.
    let pct: Int
    /// La soglia di avviso più bassa sotto il 100% (0.7); `nil` senza.
    let noticeShare: Decimal?
    /// La base "max" conta più dei crediti addebitati: "Long conversations count by size".
    let bySize: Bool
    /// Un piano per utente fuori dalla prova.
    let perUser: Bool
    /// I crediti al giorno; `nil` se nessuna fonte li dice.
    let daily: Decimal?
    /// Nel modo "day", i crediti inclusi di oggi, altrimenti `daily`.
    let todayDaily: Decimal?
    /// Il giorno di oggi del server: l'ultimo giorno di `series`, mai la data del telefono; `nil` se `series` è vuota.
    let todayDay: String?
    /// Si disegnano i contatori Today e This week: ciclo corrente, non un pool, il saldo li porta. Allora la tessera
    /// Today sparisce e l'avviso del giorno di un membro cede al contatore.
    let metersDrawn: Bool
    /// Al tetto l'uso oltre i crediti inclusi si ferma (`overage.at_spend_cap` = "stop").
    let stop: Bool
    /// Le parole dello stop, da `allowance.mode`; `nil` finché il saldo non è letto.
    let stopPeriod: AdminUsageStopPeriod?
    /// Il saldo è stato letto (e con lui il tetto).
    let capKnown: Bool
    /// Il tetto in vigore (euro); `nil` senza tetto o finché il saldo non è letto.
    let capAmount: Decimal?
    let capState: AriaSpendCapStatus?
    /// Euro addebitati contro il tetto; `nil` se ignoto o per chi non vede i soldi.
    let capBilled: Decimal?
    /// Quanto del tetto è usato, intero: solo `dashboard.spend_cap.percent`, mai calcolato qui.
    let capPct: Int?
    /// Un piano a pagamento i cui extra non si addebitano: tetto di 0 euro.
    let capZero: Bool
    /// La scheda del tetto c'è (titolare, ciclo corrente, con un piano).
    let showLimitCard: Bool
    /// La chiave del piano "Upgrade to {plan}"; `nil` se non c'è.
    let upgradeTier: String?
    /// `config.ui.sales_contact_email`; `nil` se vuoto.
    let email: String?

    init?(dashboard: AriaUsageDashboard, config: AriaUsageConfig, allowance: AriaAllowance?,
          locale: Locale = .autoupdatingCurrent) {
        guard dashboard.enabled, let period = dashboard.period, let start = period.start, let end = period.end else {
            return nil
        }
        self.dashboard = dashboard
        self.config = config
        self.allowance = allowance
        self.period = period
        self.start = start
        self.end = end
        self.locale = locale

        owner = config.canManagePlan
        closed = period.closed
        dayMode = period.mode == "day"
        trial = period.closed ? nil : dashboard.trial
        noPlan = (dashboard.tierSource ?? config.tierSource) != "assignment"
        pool = dashboard.mode == .pool
        seesMoney = !noPlan && config.amountsVisible && dashboard.amountsVisible
        textOwner = owner && seesMoney
        currency = dashboard.currency ?? config.currency ?? "EUR"
        included = period.included ?? 0
        pct = period.pct.map(AdminUsageFormat.percent) ?? 0
        let thresholds = dashboard.noticeThresholds.isEmpty ? (allowance?.noticeThresholds ?? []) : dashboard.noticeThresholds
        noticeShare = thresholds.filter { $0 > 0 && $0 < 1 }.min()
        if let credits = period.creditsUsed, let size = period.tokenEquivalent {
            bySize = period.basis == "max" && size > credits
        } else {
            bySize = false
        }
        perUser = dashboard.perUserCredits != nil && dashboard.billedUsers != nil && trial == nil

        let daily: Decimal?
        if let perUser = dashboard.perUserCredits, let users = dashboard.billedUsers {
            daily = perUser * Decimal(users)
        } else if let window = allowance?.window?.dailyAllowance {
            daily = window
        } else if let plan = config.plan?.creditsPerDay {
            daily = plan
        } else if let days = period.includedDays, days > 0, let included = period.included {
            daily = included / Decimal(days)
        } else {
            daily = nil
        }
        self.daily = daily
        todayDaily = period.mode == "day" ? (period.todayIncluded ?? daily) : daily
        todayDay = dashboard.series.last?.day
        metersDrawn = !period.closed && dashboard.mode != .pool && allowance?.meters != nil
        stop = config.atSpendCap == "stop"
        if let allowance, allowance.enabled {
            switch allowance.mode {
            case .pool?: stopPeriod = .cycle
            case .daily?: stopPeriod = .day
            case nil: stopPeriod = nil
            }
        } else {
            stopPeriod = nil
        }
        capKnown = allowance != nil
        capAmount = allowance?.spendCap?.amount
        capState = allowance?.spendCap?.state
        capBilled = allowance?.spendCap?.billed
        capPct = dashboard.spendCap?.percent
        capZero = trial == nil && !noPlan && period.extraCreditsBillable == false
        showLimitCard = config.canManagePlan && !period.closed && !noPlan
        if config.canManagePlan, trial == nil, !noPlan, !period.closed, let allowance {
            upgradeTier = config.upgradeTarget(period: allowance.period)?.key
        } else {
            upgradeTier = nil
        }
        email = config.salesContactEmail.flatMap { $0.isEmpty ? nil : $0 }
    }

    // MARK: Scritture con la lingua

    func credits(_ value: Decimal) -> String { AdminUsageFormat.credits(value, locale: locale) }
    func whole(_ value: Int) -> String { AdminUsageFormat.whole(value, locale: locale) }
    func money(_ value: Decimal) -> String { AdminUsageFormat.money(value, currency: currency, locale: locale) }
    func amount(_ value: Decimal) -> String { AdminUsageFormat.amount(value, currency: currency, locale: locale) }
    func day(_ value: String?) -> String? { value.flatMap { AdminUsageFormat.shortDay($0, locale: locale) } }
    func elide(_ text: String) -> String { AdminUsageFormat.elide(text, locale: locale) }

    /// I crediti extra non si addebitano: nessun piano non c'entra, conta `extra_credits_billable` (mancante = si addebitano).
    var extraBillable: Bool { period.extraCreditsBillable != false }

    /// Il prezzo di un credito extra scritto; `nil` se non è stato mandato o per chi non vede i soldi.
    var priceText: String? {
        guard seesMoney, let price = period.pricePerCredit else { return nil }
        return money(price)
    }

    /// Il giorno dopo la fine del ciclo, scritto: quando si azzera.
    var reset: String { day(AdminUsageFormat.nextDay(end)) ?? end }

    /// Il mese del ciclo, scritto ("November 2026").
    var monthName: String { AdminUsageFormat.monthYear(start, locale: locale) ?? start }

    /// L'ultimo giorno della prova, altrimenti il giorno dell'azzeramento.
    var trialEnd: String { day(trial?.endsOn) ?? reset }

    /// Il tetto scritto, solo per chi vede i soldi.
    var capText: String? {
        guard seesMoney, let capAmount else { return nil }
        return money(capAmount)
    }

    /// La quota di oggi nel modo "day": consumati di inclusi, intera (`today_consumed ÷ today_included`).
    var dayPct: Int {
        guard let included = period.todayIncluded, included > 0 else { return 0 }
        return AdminUsageFormat.percent((period.todayConsumed ?? 0) / included)
    }
}

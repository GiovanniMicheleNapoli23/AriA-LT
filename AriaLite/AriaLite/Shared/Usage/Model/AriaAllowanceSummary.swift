//
//  AriaAllowanceSummary.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Quello che il saldo dei crediti dice, già pronto per le view: tipo di azienda, tono, titolo e seconda riga, anello,
//  avviso, blocchi (ultime 24 h, ciclo, contatori, ultimi 7 giorni). Ricalca describeAllowance della web
//  (credit-indicator-model.ts): lo stato lo decide il server, qui non si deduce niente da una percentuale e un importo
//  `nil` non si scrive mai (né come 0). I testi stanno in AriaAllowanceSummary+Text.swift.
//

import Foundation

nonisolated struct AriaAllowanceSummary: Equatable, Sendable {
    /// Nell'ordine in cui si riconoscono: nessuna quota dichiarata, pool, crediti giornalieri.
    nonisolated enum Kind: Equatable, Sendable { case noAllowance, pool, daily }

    /// Solo da `state`: notice, pacing e overage sono `warning`, capped è `capped`; senza quota sempre `normal`.
    nonisolated enum Tone: Equatable, Sendable { case normal, warning, capped }

    /// La scatola di avviso dello stato.
    nonisolated struct Alert: Equatable, Sendable {
        nonisolated enum Severity: Equatable, Sendable { case info, warning, critical }
        let title: String
        let body: String
        let severity: Severity
        /// Proprietari e admin, con la prova esaurita: la scheda può offrire "Choose a plan".
        let offersPlanChange: Bool
    }

    /// La cifra grande della scheda con la sua etichetta ("27.6" · "credits available").
    nonisolated struct Big: Equatable, Sendable {
        let value: String
        let label: String
        let note: String?
    }

    /// Le ultime 24 ore (la finestra mobile) di un piano giornaliero: "12.4 of 40 used".
    nonisolated struct Window: Equatable, Sendable {
        let title: String
        let value: String
        let fraction: Double
        /// "Daily allowance 40: 1 user × 40", solo su un piano per utente e mai in prova.
        let note: String?
    }

    /// Il ciclo (o il giorno UTC): barra con tacca, "Resets 1 Dec", "12% used".
    nonisolated struct Cycle: Equatable, Sendable {
        let title: String
        let value: String
        /// Limitata a 0…1 (la percentuale scritta in `usedText` può invece passare 100).
        let fraction: Double
        /// Dove cade la tacca dell'avviso, 0…1.
        let tick: Double?
        let resets: String?
        let usedText: String
        /// "Long conversations count by size".
        let bySize: String?
    }

    /// Un contatore (Today, This week): non limitato a 100.
    nonisolated struct Meter: Equatable, Sendable {
        let title: String
        let value: String
        let percent: Int?
        let fraction: Double
        /// Dalla quota `warn_threshold` il contatore è ambra.
        let isWarning: Bool
        /// "Resets Nov 19": quando il contatore riparte (`resets_at`, UTC); `nil` se il server non lo manda.
        let resets: String?
    }

    nonisolated struct HistoryDay: Equatable, Sendable {
        /// `YYYY-MM-DD`, UTC.
        let day: String
        /// Giorno della settimana abbreviato.
        let label: String
        /// Solo per disegnare le barre: le cifre scritte vengono dai decimali.
        let credits: Double
    }

    /// I sette giorni UTC, dal più vecchio a oggi.
    nonisolated struct History: Equatable, Sendable {
        let days: [HistoryDay]
        /// La linea della quota giornaliera; `nil` su un pool, senza quota o se non è stato usato niente.
        let reference: Double?
        /// "avg 12 a day".
        let average: String
        let isEmpty: Bool
    }

    let kind: Kind
    let tone: Tone
    /// Lo stato del server (`ok` quando non è noto o l'azienda non ha una quota).
    let state: AriaAllowanceState
    let isTrial: Bool
    /// Nessun piano assegnato (`tier_source != "assignment"`): cifre visibili, niente fatturato.
    let isUnassigned: Bool
    let headline: String
    let subline: String?
    let big: Big
    let alert: Alert?
    /// 0…1; `nil` senza quota (anello pieno e spento).
    let ringFraction: Double?
    /// Il ciclo conta anche a dimensione: "Long conversations count by size".
    let countsBySize: Bool
    let window: Window?
    let cycle: Cycle?
    let meters: [Meter]
    let history: History?
    /// "Ends 3 Dec", con la prova in corso.
    let trialLine: String?
    /// Crediti del ciclo (del giorno UTC nel modo "day").
    let cycleUsed: Decimal?
    let cycleIncluded: Decimal?
    /// Percentuale intera usata, non limitata a 100.
    let cyclePct: Int?
    let cycleResets: Date?
    let isDayMode: Bool
    /// La tacca sulle barre: la quota più bassa sotto 1 di `notice_thresholds`.
    let tickFraction: Double?

    /// `nil` quando il saldo non va mostrato: funzione spenta (`enabled == false`), senza ciclo o con una cifra che
    /// serve e non si legge. Un decimale illeggibile è un payload malformato: nessuna cifra.
    /// `canManagePlan`: owner e admin (config `can_manage_plan`), per le frasi "No plan is assigned yet…" e della prova.
    static func make(_ allowance: AriaAllowance, now: Date = .now, locale: Locale = .autoupdatingCurrent,
                     canManagePlan: Bool = false) -> AriaAllowanceSummary? {
        guard allowance.enabled,
              let f = Figures(allowance, now: now, locale: locale, canManage: canManagePlan) else { return nil }
        let trigger = f.trigger()
        let tick = f.tick
        let cycleBlock = f.cycleBlock()
        return AriaAllowanceSummary(
            kind: f.kind, tone: f.tone, state: f.state, isTrial: f.trial, isUnassigned: f.fallback,
            headline: trigger.headline, subline: trigger.subline, big: f.big(), alert: f.alert(),
            ringFraction: trigger.ring, countsBySize: cycleBlock?.bySize != nil,
            window: f.windowBlock(), cycle: cycleBlock, meters: f.meters(), history: f.history(),
            trialLine: f.trialLine(),
            cycleUsed: f.day ? f.dayConsumed : f.consumed,
            cycleIncluded: f.kind == .noAllowance ? nil : (f.day ? f.dayIncluded : f.included),
            cyclePct: f.kind == .noAllowance ? nil : (f.day ? f.dayPct : f.cyclePct),
            cycleResets: f.period.resetsAt, isDayMode: f.day, tickFraction: tick)
    }

    // MARK: - Il quando del rinnovo

    nonisolated enum Refill: Equatable, Sendable {
        case unknown
        /// Meno di un'ora.
        case soon
        case hours(Int)
    }

    /// Quando la finestra libera di nuovo crediti: sotto un'ora "soon", altrimenti l'ora più vicina (così un rinnovo a
    /// un'ora esatta si legge "1 h" qualunque sia il ritardo del render).
    static func refillIn(_ next: Date?, now: Date) -> Refill {
        guard let next else { return .unknown }
        let minutes = Int((next.timeIntervalSince(now) / 60).rounded())
        if minutes < 60 { return .soon }
        return .hours(Int((Double(minutes) / 60).rounded()))
    }
}

// MARK: - Le cifre

nonisolated extension AriaAllowanceSummary {
    /// Le cifre del saldo, lette una volta sola: ogni testo parte da qui. `nil` se manca una cifra che serve.
    nonisolated struct Figures {
        let allowance: AriaAllowance
        let period: AriaAllowance.Period
        let window: AriaAllowance.Window?
        let kind: Kind
        let state: AriaAllowanceState
        let trial: Bool
        let fallback: Bool
        let day: Bool
        let canManage: Bool
        let locale: Locale
        let refill: Refill
        /// La lunghezza della finestra: la dice il server (`window.hours`); 24 solo se un server vecchio non la manda.
        let windowHours: Int
        let included: Decimal
        let consumed: Decimal
        let cycleShare: Decimal
        let dayIncluded: Decimal
        let dayConsumed: Decimal
        /// I crediti che restano al ciclo, mai sotto 0.
        let left: Decimal
        /// Quelli disponibili ora: la finestra, o la quota del giorno nel modo "day".
        let available: Decimal?
        let extra: Decimal?
        let amount: Decimal?
        let showMoney: Bool
        /// Oltre il 100% le risposte passano al modello leggero (nessun credito extra fatturato, con un piano assegnato).
        let lighterModel: Bool

        init?(_ allowance: AriaAllowance, now: Date, locale: Locale, canManage: Bool) {
            guard let period = allowance.period else { return nil }
            // Una cifra che il server ha mandato ma non si legge è un payload malformato: nessuna cifra, mai uno 0 o
            // un ripiego. Solo `null` o assente vuol dire "non dichiarata" (`included`) o "usa l'altra fonte".
            guard !period.unreadable.contains("included"), !period.unreadable.contains("consumed"),
                  let consumed = period.consumed ?? period.creditsUsed else { return nil }
            let window = allowance.window
            let included = period.included ?? 0
            let kind: Kind = included <= 0 ? .noAllowance : (window == nil ? .pool : .daily)
            let day = period.mode == "day" && kind == .daily
            var dayIncluded: Decimal = 0
            var dayConsumed: Decimal = 0
            if day {
                guard !period.unreadable.contains("today_included"), !period.unreadable.contains("today_consumed"),
                      let wholeDay = period.todayIncluded ?? window?.dailyAllowance, wholeDay > 0,
                      let usedToday = period.todayConsumed ?? allowance.todayCredits else { return nil }
                dayIncluded = wholeDay
                dayConsumed = usedToday
            }
            var cycleShare: Decimal = 0
            // In modalità giorno la quota del ciclo non serve: un `pct` che non si legge non toglie le cifre del giorno.
            if !day {
                guard !period.unreadable.contains("pct") else { return nil }
                if kind != .noAllowance {
                    guard let share = period.pct else { return nil }
                    cycleShare = share
                }
            }
            var available: Decimal?
            if kind == .daily {
                available = day ? max(0, dayIncluded - dayConsumed) : window?.available
                guard available != nil, day || window?.dailyAllowance != nil else { return nil }
            }
            self.allowance = allowance
            self.period = period
            self.window = window
            self.kind = kind
            self.state = kind == .noAllowance ? .ok : (allowance.state ?? .ok)
            self.trial = allowance.trial != nil
            self.fallback = allowance.tierSource != "assignment"
            self.day = day
            self.canManage = canManage
            self.locale = locale
            self.refill = AriaAllowanceSummary.refillIn(window?.nextRefillAt, now: now)
            self.windowHours = window?.hours ?? 24
            self.included = included
            self.consumed = consumed
            self.cycleShare = cycleShare
            self.dayIncluded = dayIncluded
            self.dayConsumed = dayConsumed
            self.left = max(0, included - consumed)
            self.available = available
            self.extra = day ? period.todayOverageCredits : period.overageCredits
            self.amount = day ? period.todayOverageAmount : period.overageAmount
            self.showMoney = allowance.amountsVisible && allowance.tierSource == "assignment"
            self.lighterModel = period.extraCreditsBillable == false && allowance.tierSource == "assignment"
        }

        var tone: Tone {
            switch state {
            case .ok: .normal
            case .notice, .pacing, .overage: .warning
            case .capped: .capped
            }
        }

        var cyclePct: Int { AriaCredits.percent(cycleShare) }
        var dayShare: Decimal { dayIncluded > 0 ? dayConsumed / dayIncluded : 0 }
        var dayPct: Int { AriaCredits.percent(dayShare) }
        /// La percentuale scritta nel titolo dell'avviso: del giorno o del ciclo.
        var pct: Int { day ? dayPct : cyclePct }

        /// La tacca: la quota più bassa sotto 1, a passi di un punto percentuale.
        var tick: Double? {
            guard let lowest = allowance.noticeThresholds.filter({ $0 < 1 }).min() else { return nil }
            return Double(AriaCredits.percent(lowest)) / 100
        }

        func unit(_ value: Decimal) -> Double {
            min(1, max(0, NSDecimalNumber(decimal: value).doubleValue))
        }

        /// Crediti con al più un decimale, nella lingua di chi legge.
        func number(_ value: Decimal) -> String {
            AriaCredits.format(AriaCredits.oneDecimal(value), locale: locale)
        }

        func money(_ value: Decimal) -> String {
            AriaCredits.formatMoney(value, currency: allowance.currency ?? "EUR", locale: locale)
        }

        func isOne(_ value: Decimal) -> Bool { AriaCredits.oneDecimal(value) == 1 }
    }
}

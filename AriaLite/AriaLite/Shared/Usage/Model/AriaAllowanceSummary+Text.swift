//
//  AriaAllowanceSummary+Text.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I testi del saldo dei crediti, nelle parole della web (copy `credits.indicator.*`): titolo e seconda riga, cifra
//  grande, avviso e blocchi. Solo le cifre del server, già lette in `Figures`; nessuno stato dedotto.
//

import Foundation

nonisolated extension AriaAllowanceSummary.Figures {
    // MARK: Titolo e seconda riga

    /// "refills in 3 h" / "refills in under 1 h"; `nil` quando non c'è un rinnovo.
    var refillText: String? {
        switch refill {
        case .hours(let hours): String(localized: "refills in \(hours) h")
        case .soon: String(localized: "refills in under 1 h")
        case .unknown: nil
        }
    }

    /// Titolo, seconda riga e anello (0…1, `nil` senza quota) del saldo.
    func trigger() -> (headline: String, subline: String?, ring: Double?) {
        switch state {
        case .overage:
            return (String(localized: "Extra credits in use"), overageSubline, 1)
        case .capped:
            let headline = trial ? String(localized: "Free trial credits used up") : String(localized: "Spending limit reached")
            return (headline, String(localized: "Lighter model in use"), 1)
        case .pacing:
            let count = number(AriaCredits.floorOneDecimal(left))
            return (String(localized: "\(count) left this cycle"), refillText ?? String(localized: "this cycle"), 0)
        case .ok, .notice:
            switch kind {
            case .noAllowance:
                let count = number(consumed)
                let headline = isOne(consumed) ? String(localized: "1 credit used") : String(localized: "\(count) credits used")
                return (headline, String(localized: "this cycle"), nil)
            case .daily:
                let free = AriaCredits.floorOneDecimal(available ?? 0)
                let count = number(free)
                let headline = isOne(free) ? String(localized: "1 credit available") : String(localized: "\(count) credits available")
                let subline = day
                    ? String(localized: "resets at 00:00 UTC")
                    : (refillText ?? String(localized: "Nothing used in \(windowHours) h"))
                let wholeDay = day ? dayIncluded : (window?.dailyAllowance ?? 0)
                return (headline, subline, wholeDay > 0 ? unit((available ?? 0) / wholeDay) : 0)
            case .pool:
                let free = AriaCredits.floorOneDecimal(left)
                let count = number(free)
                let headline = isOne(free) ? String(localized: "1 credit in pool") : String(localized: "\(count) credits in pool")
                let subline = period.resetsAt.map { String(localized: "resets \(AriaUsageDay.short($0, locale: locale))") }
                return (headline, subline, unit(left / included))
            }
        }
    }

    /// La seconda riga dell'overage: l'importo a chi vede i soldi, altrimenti i crediti oltre il piano.
    private var overageSubline: String? {
        let count = extra.map(number)
        if allowance.tierSource != "assignment", canManage, let count {
            return String(localized: "\(count) extra, not billed")
        }
        if showMoney, let amount {
            let text = money(amount)
            return day ? String(localized: "\(text) today") : String(localized: "\(text) so far")
        }
        guard let count else { return nil }
        return day ? String(localized: "\(count) over today’s credits") : String(localized: "\(count) over your plan")
    }

    // MARK: Cifra grande

    /// Il rinnovo spiegato per esteso, sotto la cifra grande.
    private var refillNote: String? {
        switch refill {
        case .hours(let hours): String(localized: "Credits return \(windowHours) hours after use. Next refill in \(hours) h.")
        case .soon: String(localized: "Credits return \(windowHours) hours after use. Next refill in under 1 h.")
        case .unknown: nil
        }
    }

    func big() -> AriaAllowanceSummary.Big {
        if kind == .noAllowance {
            let label = isOne(consumed) ? String(localized: "credit used this cycle") : String(localized: "credits used this cycle")
            return .init(value: number(consumed), label: label, note: nil)
        }
        if state == .overage || (state == .capped && !trial) {
            let value = extra.map(number) ?? "–"
            let one = extra.map(isOne) ?? false
            let label = switch (day, one) {
            case (true, true): String(localized: "extra credit today")
            case (true, false): String(localized: "extra credits today")
            case (false, true): String(localized: "extra credit this cycle")
            case (false, false): String(localized: "extra credits this cycle")
            }
            return .init(value: value, label: label, note: nil)
        }
        if state == .capped {
            return .init(value: number(0), label: String(localized: "credits available"), note: nil)
        }
        if state == .pacing {
            return .init(value: number(AriaCredits.floorOneDecimal(left)), label: String(localized: "left this cycle"), note: refillNote)
        }
        if kind == .daily {
            let free = AriaCredits.floorOneDecimal(available ?? 0)
            let label = isOne(free) ? String(localized: "credit available") : String(localized: "credits available")
            let note = day
                ? String(localized: "Today’s credits reset at 00:00 UTC.")
                : (refillNote ?? String(localized: "You haven’t used any credits in the last \(windowHours) hours."))
            return .init(value: number(free), label: label, note: note)
        }
        let free = AriaCredits.floorOneDecimal(left)
        let label = isOne(free) ? String(localized: "credit left in the pool") : String(localized: "credits left in the pool")
        return .init(value: number(free), label: label, note: nil)
    }

    // MARK: Avviso

    /// L'avviso dello stato; mai per un'azienda senza quota. Il corpo di un notice segue se i crediti extra si
    /// fatturano, non il nome del piano.
    func alert() -> AriaAllowanceSummary.Alert? {
        guard kind != .noAllowance else { return nil }
        switch state {
        case .ok: return nil
        case .notice:
            let title = day
                ? String(localized: "\(pct)% of today’s credits used")
                : (trial ? String(localized: "\(pct)% of your free trial credits used") : String(localized: "\(pct)% of this cycle used"))
            let body = switch (day, lighterModel) {
            case (true, true): String(localized: "You can keep working. Beyond 100% today, answers use a lighter model.")
            case (true, false): String(localized: "You can keep working. Beyond 100% today, extra credits are used.")
            case (false, true): String(localized: "You can keep working. Beyond 100%, answers use a lighter model.")
            case (false, false): String(localized: "You can keep working. Beyond 100%, extra credits are used.")
            }
            return .init(title: title, body: body, severity: .warning, offersPlanChange: false)
        case .pacing:
            let count = number(AriaCredits.floorOneDecimal(left))
            return .init(title: String(localized: "Today’s share is used"),
                         body: String(localized: "Your plan still has \(count) credits this cycle and nothing extra is charged. More credits return as your last \(windowHours) hours roll off."),
                         severity: .info, offersPlanChange: false)
        case .overage:
            guard let body = overageBody else { return nil }
            let title = day ? String(localized: "Today’s credits are used up") : String(localized: "You’re using extra credits")
            return .init(title: title, body: body, severity: .warning, offersPlanChange: false)
        case .capped:
            if trial {
                let body = canManage
                    ? String(localized: "The free trial has no extra credits. Answers use a lighter model until you choose a plan.")
                    : String(localized: "The free trial has no extra credits. Answers use a lighter model. Ask an owner to change plan.")
                return .init(title: String(localized: "Free trial credits used up"), body: body, severity: .critical,
                             offersPlanChange: canManage)
            }
            let body: String
            if showMoney, let cap = allowance.spendCapAmount {
                let limit = money(cap)
                body = String(localized: "Your limit of \(limit) for this cycle is reached. Answers now use a lighter model and nothing more is billed.")
            } else {
                body = String(localized: "Your company’s spending limit for this cycle is reached. Answers now use a lighter model.")
            }
            return .init(title: String(localized: "Spending limit reached"), body: body, severity: .critical, offersPlanChange: false)
        }
    }

    private var overageBody: String? {
        if allowance.tierSource != "assignment", canManage {
            return String(localized: "No plan is assigned yet; your company runs on Basic. Extra credits are not billed, and work continues as usual.")
        }
        if showMoney, let amount, let price = period.pricePerCredit {
            let total = money(amount)
            let each = money(price)
            return day
                ? String(localized: "\(total) so far today, at \(each) per extra credit. Work continues as usual; the included credits start again at 00:00 UTC.")
                : String(localized: "\(total) so far, at \(each) per extra credit. Work continues as usual.")
        }
        guard let extra else { return nil }
        let credits = AriaCredits.phrase(AriaCredits.oneDecimal(extra), locale: locale)
        return day
            ? String(localized: "\(credits) beyond today’s credits. Work continues as usual.")
            : String(localized: "\(credits) beyond your plan this cycle. Work continues as usual.")
    }

    // MARK: Blocchi

    /// Le ultime ore (la finestra mobile) di un piano giornaliero; non nel modo "day".
    func windowBlock() -> AriaAllowanceSummary.Window? {
        guard kind == .daily, !day, let window, let total = window.dailyAllowance, let free = window.available else { return nil }
        let used = min(total, max(0, total - free))
        let value = String(localized: "\(number(used)) of \(number(total)) used")
        var note: String?
        if let perUser = window.perUserCredits, !trial {
            let totalText = number(total)
            let perUserText = number(perUser)
            let users = window.billedUsers ?? 0
            note = users == 1
                ? String(localized: "Daily allowance \(totalText): 1 user × \(perUserText)")
                : String(localized: "Daily allowance \(totalText): \(users) users × \(perUserText)")
        }
        return .init(title: String(localized: "Last \(windowHours) hours"), value: value,
                     fraction: total > 0 ? unit(used / total) : 0, note: note)
    }

    /// La prova cade dentro questo ciclo: la scheda dice "Your trial · Ends …" al posto del ciclo.
    private var trialInPeriod: Bool {
        guard trial, let span = allowance.trial, let from = span.startsOn, let to = span.endsOn,
              let start = period.start, let end = period.end else { return false }
        return from >= start && to <= end
    }

    func cycleBlock() -> AriaAllowanceSummary.Cycle? {
        guard kind != .noAllowance else { return nil }
        let resetDate = period.resetsAt.map { AriaUsageDay.short($0, locale: locale) }
        if day {
            return .init(title: String(localized: "Today (UTC)"),
                         value: String(localized: "\(number(dayConsumed)) of \(number(dayIncluded))"),
                         fraction: unit(dayShare), tick: tick, resets: String(localized: "Resets at 00:00 UTC"),
                         usedText: String(localized: "\(dayPct)% used"), bySize: nil)
        }
        let inTrial = trialInPeriod
        var resets: String?
        if inTrial, let ends = allowance.trial?.endsOn.flatMap({ AriaUsageDay.short($0, locale: locale) }) {
            resets = String(localized: "Ends \(ends)")
        } else if let resetDate {
            resets = String(localized: "Resets \(resetDate)")
        }
        // I crediti lunghi contano per dimensione (UX-D17): il ciclo conta l'equivalente in token, sopra i crediti addebitati.
        var bySize: String?
        if period.basis == "max", let tokens = period.tokenEquivalent, let charged = period.creditsUsed, tokens > charged {
            bySize = String(localized: "Long conversations count by size")
        }
        return .init(title: inTrial ? String(localized: "Your trial") : String(localized: "This cycle"),
                     value: String(localized: "\(number(consumed)) of \(number(included))"),
                     fraction: unit(cycleShare), tick: tick, resets: resets,
                     usedText: String(localized: "\(cyclePct)% used"), bySize: bySize)
    }

    /// "Ends 3 Dec", con la prova in corso.
    func trialLine() -> String? {
        guard let ends = allowance.trial?.endsOn, let date = AriaUsageDay.short(ends, locale: locale) else { return nil }
        return String(localized: "Ends \(date)")
    }

    /// I contatori Today e This week; senza usato o incluso non si disegnano.
    func meters() -> [AriaAllowanceSummary.Meter] {
        guard let meters = allowance.meters else { return [] }
        var result: [AriaAllowanceSummary.Meter] = []
        for (title, meter) in [(String(localized: "Today"), meters.today), (String(localized: "This week"), meters.week)] {
            guard let meter, let used = meter.used, let included = meter.included else { continue }
            let share: Decimal = included > 0 ? used / included : 0
            result.append(.init(title: title, value: String(localized: "\(number(used)) of \(number(included))"),
                                percent: meter.percent, fraction: unit(share),
                                isWarning: meter.warnThreshold.map { included > 0 && share >= $0 } ?? false,
                                resets: meter.resetsAt.map { String(localized: "Resets \(AriaUsageDay.short($0, locale: locale))") }))
        }
        return result
    }

    // MARK: Ultimi sette giorni

    func history() -> AriaAllowanceSummary.History? {
        // Un giorno con i crediti illeggibili o `null` non si disegna come 0 e non entra nella media.
        let readable = allowance.lastDays.compactMap { day in day.credits.map { (day: day.day, credits: $0) } }
        guard !readable.isEmpty else { return nil }
        let used = readable.contains { $0.credits > 0 }
        let reference = kind == .daily ? (window?.dailyAllowance ?? 0) : 0
        let mean = AriaCredits.wholeNumber(readable.reduce(Decimal(0)) { $0 + $1.credits } / Decimal(readable.count))
        let average = AriaCredits.format(mean, locale: locale)
        return .init(
            days: readable.map {
                AriaAllowanceSummary.HistoryDay(
                    day: $0.day, label: AriaUsageDay.weekday($0.day, locale: locale) ?? $0.day,
                    credits: NSDecimalNumber(decimal: $0.credits).doubleValue)
            },
            reference: used && reference > 0 ? NSDecimalNumber(decimal: reference).doubleValue : nil,
            average: String(localized: "avg \(average) a day"), isEmpty: !used)
    }
}

//
//  AdminUsageSpendCapBuilder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Spending limit" del titolare (contratto 5.1, `spend-cap-card.tsx` della web): prova, nessun limite o un
//  limite in vigore. Funzioni pure sui fatti della pagina e sulla scheda di GET /v1/usage/spend-cap. Nessuna cifra nasce
//  qui: la quota usata è `dashboard.spend_cap.percent` del server (la web la calcola da sé: contratto 1 vince).
//  Una frase che vuole una cifra non arrivata si tralascia, mai 0 al suo posto.
//

import Foundation

nonisolated enum AdminUsageSpendCapBuilder {
    /// La scheda per questo stato di lettura: `cap` è `nil` finché non si legge (o dopo un errore).
    static func card(_ f: AdminUsageFacts, cap: AriaSpendCapView?, phase: AdminUsagePhase,
                     saveFailed: Bool = false) -> AdminUsageSpendCapCard {
        let trial = cap?.isTrial == true
        // Il limite si ferma invece di degradare solo fuori dalla prova (la prova ha le sue parole).
        let stop = f.stop && !trial
        let title = String(localized: "usage.spendCap.title", defaultValue: "Spending limit")
        let description = stop
            ? String(localized: "A limit per cycle on extra credits, in EUR. At the limit, usage past the included credits stops and nothing more is billed.")
            : String(localized: "A limit per cycle on extra credits, in EUR. Past it, AriA answers with a lighter model and nothing more is billed.")
        func make(_ content: AdminUsageSpendCapCard.Content) -> AdminUsageSpendCapCard {
            AdminUsageSpendCapCard(title: title, description: description, content: content)
        }
        guard let cap else {
            if phase == .failed {
                return make(.failed(String(localized: "The spending limit could not be loaded. Replies are not affected.")))
            }
            return make(.loading)
        }
        if trial { return make(.trial(trialCard(f, cap: cap))) }
        guard let amount = cap.amount else { return make(.noLimit(noLimit(f))) }
        return make(.inForce(inForce(f, cap: cap, amount: amount, stop: stop, saveFailed: saveFailed)))
    }

    // MARK: Interno

    private static func currency(_ f: AdminUsageFacts, _ cap: AriaSpendCapView) -> String {
        cap.currency ?? f.currency
    }

    static func money(_ value: Decimal, _ f: AdminUsageFacts, _ cap: AriaSpendCapView) -> String {
        AdminUsageFormat.money(value, currency: currency(f, cap), locale: f.locale)
    }

    /// Il prezzo di un credito extra della config (mai 0: `nil` per chi non vede i soldi).
    static func priceText(_ f: AdminUsageFacts, _ cap: AriaSpendCapView) -> String? {
        f.config.pricePerCredit.map { money($0, f, cap) }
    }

    // MARK: Prova

    private static func trialCard(_ f: AdminUsageFacts, cap: AriaSpendCapView) -> AdminUsageSpendCapCard.Trial {
        let ends = f.allowance?.trial?.endsOn ?? f.config.trial?.endsOn
        let reached = f.allowance?.state == .capped
        let body: String
        if reached, let date = f.day(ends) {
            body = String(localized: "The trial's included credits are used, so replies use a lighter model until the trial ends on \(date). Extra credits are never billed during the free trial. You can set your own limit once your plan starts.")
        } else {
            body = String(localized: "During the free trial extra credits are never billed. You can set your own limit once your plan starts.")
        }
        var since: String?
        if let from = cap.effectiveFrom, let date = AdminUsageFormat.shortDay(of: from, locale: f.locale) {
            since = String(localized: "per cycle · since \(date)")
        }
        var choose: AdminUsageMailAction?
        if let action = AdminUsageAlertBuilder.choosePlan(f), case .plan(let url) = action.kind {
            choose = AdminUsageMailAction(label: action.label, url: url)
        }
        return AdminUsageSpendCapCard.Trial(
            // La prova ha sempre €0 di limite: il server non manda un importo vuoto.
            amount: money(cap.amount ?? 0, f, cap),
            chip: String(localized: "Free trial"), since: since, body: body, choosePlan: choose)
    }

    // MARK: Nessun limite

    private static func noLimit(_ f: AdminUsageFacts) -> AdminUsageSpendCapCard.NoLimit {
        var body: String?
        if let price = f.config.pricePerCredit {
            let text = AdminUsageFormat.money(price, currency: f.currency, locale: f.locale)
            body = String(localized: "Extra credits are billed at \(text) each, with no upper limit.")
        }
        return AdminUsageSpendCapCard.NoLimit(chip: String(localized: "usage.spendCap.noLimit", defaultValue: "No limit"), body: body)
    }

    // MARK: Limite in vigore

    private static func inForce(_ f: AdminUsageFacts, cap: AriaSpendCapView, amount: Decimal, stop: Bool,
                                saveFailed: Bool) -> AdminUsageSpendCapCard.InForce {
        // Lo stato lo decide il server: prima quello del saldo, poi quello della scheda.
        let state = f.capState ?? cap.status ?? .ok
        let reached = state == .reached
        let warned = state == .warned
        let limitText = money(amount, f, cap)
        let price = priceText(f, cap)
        let alwaysOn = f.config.spendCapDefaultEur != nil

        var credits: String?
        if let equivalent = cap.creditsEquivalent {
            let figure = AdminUsageFormat.whole(equivalent, locale: f.locale)
            credits = String(localized: "= \(figure) credits")
        }

        // "per cycle · since {date}" o "per cycle · default for your plan", poi "at {price} per credit".
        var basis: String?
        if cap.origin == .default {
            basis = String(localized: "per cycle · default for your plan")
        } else if let from = cap.effectiveFrom, let date = AdminUsageFormat.shortDay(of: from, locale: f.locale) {
            basis = String(localized: "per cycle · since \(date)")
        }
        var subline: String?
        if let basis {
            subline = [basis, price.map { String(localized: "at \($0) per credit") }].compactMap { $0 }.joined(separator: " · ")
        }

        return AdminUsageSpendCapCard.InForce(
            amount: limitText, credits: credits,
            chip: reached ? String(localized: "usage.spendCap.reached", defaultValue: "Reached")
                : String(localized: "usage.spendCap.inForce", defaultValue: "In force"),
            isReached: reached, subline: subline,
            used: used(f, cap: cap, amount: amount, limitText: limitText, reached: reached, warned: warned),
            warnedNote: warned ? warnedNote(f, limitText: limitText, stop: stop) : nil,
            reachedNote: reached ? reachedNote(f, amount: amount, stop: stop) : nil,
            alwaysOnNote: alwaysOn ? String(localized: "This limit is always on. You can change the amount, but not remove it.") : nil,
            changeLabel: reached && stop ? String(localized: "Raise the limit")
                : reached ? String(localized: "Change limit")
                : String(localized: "usage.spendCap.change", defaultValue: "Change"),
            changeIsProminent: reached && stop,
            canRemove: amount > 0 && !alwaysOn,
            removeLabel: String(localized: "Remove limit"),
            saveError: saveFailed ? String(localized: "The limit was not saved. Try again.") : nil)
    }

    /// "{billed} of {limit} used this cycle · {credits} of {credits} credits", con la barra. Si tralascia finché
    /// `allowance.spend_cap.billed` non è noto e per un limite di €0.
    private static func used(_ f: AdminUsageFacts, cap: AriaSpendCapView, amount: Decimal, limitText: String,
                             reached: Bool, warned: Bool) -> AdminUsageSpendCapCard.Used? {
        guard amount > 0, let billed = f.capBilled else { return nil }
        let billedText = AdminUsageFormat.amount(billed, currency: currency(f, cap), locale: f.locale)
        var parts = [String(localized: "\(billedText) of \(limitText) used this cycle")]
        if let billedCredits = f.dashboard.spendCap?.billedCredits, let equivalent = cap.creditsEquivalent {
            let a = AdminUsageFormat.whole(billedCredits, locale: f.locale)
            let b = AdminUsageFormat.whole(equivalent, locale: f.locale)
            parts.append(String(localized: "\(a) of \(b) credits"))
        }
        // La barra segue la quota che manda il server, fermata a 100: l'app non divide usato per limite.
        let fill = f.capPct.map { Double(min(100, max(0, $0))) / 100 }
        return AdminUsageSpendCapCard.Used(text: parts.joined(separator: " · "), fill: fill,
                                           tone: reached ? .over : warned ? .warning : .normal)
    }

    /// "{pct}% of your limit is used. At {limit}, AriA switches to a lighter model." (o la versione "stop" del giorno o del ciclo).
    private static func warnedNote(_ f: AdminUsageFacts, limitText: String, stop: Bool) -> String? {
        guard let percent = f.capPct else { return nil }
        let pct = f.whole(percent)
        let text: String
        if stop {
            guard let period = f.stopPeriod else { return nil }
            text = period == .day
                ? String(localized: "\(pct)% of your limit is used. At \(limitText), usage past each day's included credits stops.")
                : String(localized: "\(pct)% of your limit is used. At \(limitText), usage past the included credits stops.")
        } else {
            text = String(localized: "\(pct)% of your limit is used. At \(limitText), AriA switches to a lighter model.")
        }
        return f.elide(text)
    }

    /// Il limite è raggiunto: dove il piano si ferma, le parole del giorno o del ciclo; altrimenti "lighter model" e,
    /// per un limite di €0, "Extra credits are never billed.".
    private static func reachedNote(_ f: AdminUsageFacts, amount: Decimal, stop: Bool) -> String? {
        let date = f.reset
        if stop {
            guard let period = f.stopPeriod else { return nil }
            return period == .day
                ? String(localized: "Until \(date), usage past each day's included credits stops. Usage within the daily credits still works. Raise the limit to resume right away.")
                : String(localized: "Until \(date), usage past the included credits stops. Usage within the included credits still works. Raise the limit to resume right away.")
        }
        var text = f.dayMode
            ? String(localized: "Past each day's included credits, replies use a lighter model until \(date). Nothing is billed past the limit.")
            : String(localized: "Replies use a lighter model until \(date). Nothing is billed past the limit.")
        if amount == 0 { text += " " + String(localized: "Extra credits are never billed.") }
        return text
    }
}

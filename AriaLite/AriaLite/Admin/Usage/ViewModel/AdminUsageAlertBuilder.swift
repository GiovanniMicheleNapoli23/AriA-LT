//
//  AdminUsageAlertBuilder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'avviso che apre la pagina (contratto 3.3, `status-alert.ts` della web): al più uno, il primo caso che vale nell'ordine
//  chiuso, prova, tetto, modo "day", nessun piano, ciclo. Chi vede i soldi legge le frasi con gli euro; gli altri quelle
//  in soli crediti. Una frase che vuole una cifra non arrivata si tralascia: mai 0 al suo posto.
//

import Foundation

nonisolated enum AdminUsageAlertBuilder {
    /// L'avviso del ciclo, o `nil` quando non ce n'è nessuno (ciclo "ok" o "pacing", il contatore di oggi per un membro).
    static func build(_ f: AdminUsageFacts) -> AdminUsageAlert? {
        if f.closed { return closed(f) }
        if f.trial != nil { return trial(f) }
        if let cap = capAlert(f) { return cap }
        if f.dayMode { return day(f) }
        if f.noPlan { return noPlan(f) }
        return cycle(f)
    }

    // MARK: Ciclo chiuso

    private static func closed(_ f: AdminUsageFacts) -> AdminUsageAlert {
        let month = f.monthName
        return AdminUsageAlert(
            tone: .info,
            title: String(localized: "You're viewing \(month), a closed cycle"),
            body: f.owner
                ? String(localized: "These figures are final. Today, the projection and the billing controls apply only to the current cycle.")
                : String(localized: "These figures are final. Today and the projection apply only to the current cycle."),
            actions: [AdminUsageAlertAction(kind: .back, label: String(localized: "Back to the current cycle"))])
    }

    // MARK: Prova gratuita

    private static func trial(_ f: AdminUsageFacts) -> AdminUsageAlert {
        let date = f.trialEnd
        let state = f.dashboard.state
        let head: AdminUsageAlert
        if state == .capped {
            if f.owner {
                let included = f.credits(f.included)
                head = AdminUsageAlert(
                    tone: .warning,
                    title: String(localized: "Trial credits used: replies use a lighter model"),
                    body: String(localized: "Your free trial's \(included) credits are used. Until the trial ends on \(date), AriA answers with a lighter model and nothing is billed. To keep the standard model, choose a plan."))
            } else {
                head = AdminUsageAlert(
                    tone: .warning,
                    title: String(localized: "Replies use a lighter model until \(date)"),
                    body: String(localized: "Your company has used the free trial's included credits. An owner can choose a plan."))
            }
        } else if state == .notice, let over = f.dashboard.projection?.overageCredits, over > 0 {
            // L'avviso della prova dice che i crediti finiscono prima della fine: vale solo se la proiezione li supera.
            let pct = f.whole(f.pct)
            head = AdminUsageAlert(
                tone: .warning,
                title: f.elide(String(localized: "\(pct)% of the free trial's credits used")),
                body: String(localized: "At this pace the included credits run out before the trial ends on \(date). After that, AriA answers with a lighter model; nothing is billed."))
        } else {
            var body: String?
            if let daily = f.daily.map(f.credits) {
                let zero = f.money(0)
                body = String(localized: "Your trial includes \(daily) credits a day for your one user. The spending limit is \(zero), so extra credits are never billed: past the included credits, AriA answers with a lighter model.")
            }
            head = AdminUsageAlert(tone: .info, title: trialTitle(f), body: body)
        }
        var result = head
        result.actions = [choosePlan(f)].compactMap { $0 }
        return result
    }

    /// "Free trial · 5 days left"; senza i giorni mandati, il titolo da solo.
    private static func trialTitle(_ f: AdminUsageFacts) -> String {
        guard let days = f.trial?.daysLeft else { return String(localized: "Free trial") }
        let count = f.whole(days)
        return days == 1
            ? String(localized: "Free trial · \(count) day left")
            : String(localized: "Free trial · \(count) days left")
    }

    // MARK: Azioni

    /// "Upgrade to {plan}": il primo piano più alto con più crediti; solo un titolare, e c'è un indirizzo.
    static func upgrade(_ f: AdminUsageFacts) -> AdminUsageAlertAction? {
        guard let key = f.upgradeTier, let email = f.email else { return nil }
        let plan = AdminUsageWords.planName(key)
        return mail(label: String(localized: "Upgrade to \(plan)"), subject: String(localized: "AriA plan request: \(plan)"), email: email)
    }

    /// "Choose a plan" (prova): solo un titolare, e c'è un indirizzo. L'oggetto della mail è l'etichetta.
    static func choosePlan(_ f: AdminUsageFacts) -> AdminUsageAlertAction? {
        guard f.owner, let email = f.email else { return nil }
        let label = String(localized: "Choose a plan")
        return mail(label: label, subject: label, email: email)
    }

    /// "Set a spending limit" senza tetto, "Change limit" con uno; niente finché il saldo non è letto.
    static func limit(_ f: AdminUsageFacts) -> AdminUsageAlertAction? {
        guard f.showLimitCard, f.trial == nil, f.capKnown else { return nil }
        return AdminUsageAlertAction(
            kind: .limit,
            label: f.capAmount == nil ? String(localized: "Set a spending limit") : String(localized: "Change limit"))
    }

    static func changeLimit(_ f: AdminUsageFacts) -> AdminUsageAlertAction? {
        guard f.showLimitCard, f.trial == nil else { return nil }
        return AdminUsageAlertAction(kind: .limit, label: String(localized: "Change limit"))
    }

    /// Al tetto raggiunto sotto "stop" l'unica via d'uscita è alzarlo.
    static func raiseLimit(_ f: AdminUsageFacts) -> AdminUsageAlertAction? {
        guard f.showLimitCard, f.trial == nil else { return nil }
        return AdminUsageAlertAction(kind: .limit, label: String(localized: "Raise the limit"))
    }

    /// "Set a spending limit" solo con il saldo letto e nessun tetto in vigore (avvisi `notice`).
    static func limitWhenNoneInForce(_ f: AdminUsageFacts) -> AdminUsageAlertAction? {
        f.capKnown && f.capAmount == nil ? limit(f) : nil
    }

    private static func mail(label: String, subject: String, email: String) -> AdminUsageAlertAction? {
        AdminUsageMail.url(email: email, subject: subject).map { AdminUsageAlertAction(kind: .plan($0), label: label) }
    }
}

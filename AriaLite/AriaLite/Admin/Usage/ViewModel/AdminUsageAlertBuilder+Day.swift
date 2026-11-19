//
//  AdminUsageAlertBuilder+Day.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il caso 4 dell'avviso: il modo "day", dove i crediti del piano si giudicano per giorno UTC. Un membro non ha
//  l'avviso del giorno dove il contatore Today è disegnato: il contatore è l'avviso.
//

import Foundation

nonisolated extension AdminUsageAlertBuilder {
    static func day(_ f: AdminUsageFacts) -> AdminUsageAlert? {
        switch f.dashboard.state {
        case .notice?: dayNotice(f)
        case .overage?: dayOverage(f)
        case .capped?: dayCapped(f)
        default: nil
        }
    }

    private static func dayNotice(_ f: AdminUsageFacts) -> AdminUsageAlert? {
        if !f.owner, f.metersDrawn { return nil }
        let pct = f.whole(f.dayPct)
        let daily = f.period.todayIncluded.map(f.credits)
        let noExtra = !f.extraBillable
        let head: AdminUsageAlert
        // L'avviso del titolare va a chi vede i soldi, e a un titolare i cui extra non si addebitano.
        if f.owner, f.textOwner || noExtra {
            var body: String?
            if f.noPlan {
                body = String(localized: "No plan is assigned yet; your company runs on Basic. Extra credits are not billed, and work continues as usual.")
            } else if let daily {
                if noExtra {
                    if let cap = f.capText {
                        body = String(localized: "Past today's \(daily) included credits, answers use a lighter model until the day resets at 00:00 UTC. With a limit of \(cap), nothing extra is billed.")
                    } else {
                        body = String(localized: "Past today's \(daily) included credits, replies use a lighter model until 00:00 UTC. Owners have been notified.")
                    }
                } else if let price = f.priceText {
                    body = String(localized: "Past today's \(daily) included credits, extra credits are billed at \(price) each until the day resets at 00:00 UTC.")
                }
            }
            head = AdminUsageAlert(tone: .warning,
                                   title: f.elide(String(localized: "You've used \(pct)% of today's credits")), body: body)
        } else {
            var body: String?
            if let daily {
                // Senza piano le risposte continuano come sempre: mai la riga del "modello più leggero".
                body = noExtra && !f.noPlan
                    ? String(localized: "Past today's \(daily) included credits, replies use a lighter model until 00:00 UTC. Owners have been notified.")
                    : String(localized: "Past today's \(daily) included credits, extra credits are used until 00:00 UTC. Owners have been notified.")
            }
            head = AdminUsageAlert(tone: .warning,
                                   title: f.elide(String(localized: "Your company has used \(pct)% of today's credits")), body: body)
        }
        var result = head
        result.actions = [limitWhenNoneInForce(f), upgrade(f)].compactMap { $0 }
        return result
    }

    private static func dayOverage(_ f: AdminUsageFacts) -> AdminUsageAlert {
        let daily = f.period.todayIncluded.map(f.credits)
        let extra = f.credits(f.period.todayOverageCredits ?? 0)
        let head: AdminUsageAlert
        if f.textOwner, let over = f.period.todayOverageAmount, let price = f.priceText, let daily {
            let amount = f.amount(over)
            head = AdminUsageAlert(
                tone: .warning,
                title: String(localized: "Today's credits are used up: \(amount) extra today"),
                body: String(localized: "\(extra) credits past today's \(daily) included, at \(price) per credit. Answers continue as usual; the included credits start again at 00:00 UTC."))
        } else {
            head = AdminUsageAlert(
                tone: .warning,
                title: String(localized: "Today's credits are used up"),
                body: daily.map { daily in
                    String(localized: "\(extra) credits past today's \(daily) included. Answers continue as usual, using extra credits.")
                })
        }
        var result = head
        result.actions = [limit(f), upgrade(f)].compactMap { $0 }
        return result
    }

    private static func dayCapped(_ f: AdminUsageFacts) -> AdminUsageAlert {
        let head: AdminUsageAlert
        if f.textOwner {
            var body: String?
            if let cap = f.capText, let daily = f.period.todayIncluded.map(f.credits) {
                let date = f.reset
                body = String(localized: "Your limit of \(cap) is reached, so nothing more is billed this cycle. Each day, past its \(daily) included credits, AriA answers with a lighter model until the cycle resets on \(date). Raise the limit to go back to the standard model.")
            }
            head = AdminUsageAlert(tone: .critical,
                                   title: String(localized: "Spending limit reached: past today's credits, replies use a lighter model"),
                                   body: body)
        } else {
            head = AdminUsageAlert(tone: .critical,
                                   title: String(localized: "Past today's credits, replies use a lighter model"),
                                   body: String(localized: "Your company reached its spending limit. An owner can raise it."))
        }
        var result = head
        result.actions = [changeLimit(f), upgrade(f)].compactMap { $0 }
        return result
    }
}

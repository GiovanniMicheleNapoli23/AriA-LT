//
//  AdminUsageAlertBuilder+Cycle.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I casi 5 e 6 dell'avviso: nessun piano assegnato (cifre di Basic, niente addebiti) e il ciclo ordinario. Un titolare
//  che non vede i soldi legge le parole del membro.
//

import Foundation

nonisolated extension AdminUsageAlertBuilder {
    // MARK: Nessun piano

    static func noPlan(_ f: AdminUsageFacts) -> AdminUsageAlert? {
        let extra = f.credits(f.period.overageCredits ?? 0)
        let included = f.credits(f.included)
        let projection = f.dashboard.projection
        switch f.dashboard.state {
        case .overage?:
            if f.owner {
                return AdminUsageAlert(
                    tone: .info,
                    title: String(localized: "No plan is assigned yet; your company runs on Basic."),
                    body: String(localized: "\(extra) credits past the \(included) included this cycle. They are not billed while no plan is assigned, and answers continue as usual."))
            }
            return AdminUsageAlert(
                tone: .warning,
                title: String(localized: "Your company is using extra credits"),
                body: String(localized: "\(extra) credits past the \(included) included this cycle. Replies work as usual."))
        case .notice?:
            let pct = f.whole(f.pct)
            if f.owner {
                return AdminUsageAlert(
                    tone: .warning,
                    title: f.elide(String(localized: "You've used \(pct)% of this cycle's credits")),
                    body: String(localized: "No plan is assigned yet; your company runs on Basic. Extra credits are not billed, and work continues as usual."))
            }
            return AdminUsageAlert(
                tone: .warning,
                title: f.elide(String(localized: "Your company has used \(pct)% of this cycle's credits")),
                body: projectedMemberBody(f, projection))
        default:
            return f.owner
                ? AdminUsageAlert(tone: .info, title: String(localized: "No plan is assigned yet; your company runs on Basic."))
                : nil
        }
    }

    // MARK: Ciclo

    static func cycle(_ f: AdminUsageFacts) -> AdminUsageAlert? {
        switch f.dashboard.state {
        case .notice?: cycleNotice(f)
        case .overage?: cycleOverage(f)
        case .capped?: cycleCapped(f)
        default: nil
        }
    }

    private static func cycleNotice(_ f: AdminUsageFacts) -> AdminUsageAlert {
        let projection = f.dashboard.projection
        let pct = f.whole(f.pct)
        let head: AdminUsageAlert
        if f.textOwner {
            var body: String?
            if f.capZero {
                body = String(localized: "You can keep working. Beyond 100%, answers use a lighter model.")
            } else if let projection, let over = projection.overageCredits, over > 0, let price = f.priceText,
                      let total = projection.overageAmount, let until = f.day(projection.until) {
                let extra = f.credits(over)
                let date = until
                let amount = f.amount(total)
                body = String(localized: "At this pace your company will use about \(extra) extra credits by \(date), billed at \(price) each (≈ \(amount)).")
            }
            let title = f.pool
                ? String(localized: "You've used \(pct)% of this month's credit pool")
                : String(localized: "You've used \(pct)% of this cycle's credits")
            head = AdminUsageAlert(tone: .warning, title: f.elide(title), body: body)
        } else {
            head = AdminUsageAlert(
                tone: .warning,
                title: f.elide(String(localized: "Your company has used \(pct)% of this cycle's credits")),
                body: projectedMemberBody(f, projection))
        }
        var result = head
        result.actions = [limitWhenNoneInForce(f), upgrade(f)].compactMap { $0 }
        return result
    }

    private static func cycleOverage(_ f: AdminUsageFacts) -> AdminUsageAlert {
        let extra = f.credits(f.period.overageCredits ?? 0)
        let included = f.credits(f.included)
        let head: AdminUsageAlert
        if f.textOwner, let over = f.period.overageAmount, let price = f.priceText {
            let amount = f.amount(over)
            var body: String?
            // Se c'è un tetto lo dice solo il saldo letto.
            if f.capKnown {
                if let capAmount = f.capAmount {
                    let cap = f.money(capAmount)
                    body = String(localized: "\(extra) credits past the \(included) included, at \(price) per credit. Your spending limit is \(cap) per cycle.")
                } else {
                    let date = f.reset
                    body = String(localized: "\(extra) credits past the \(included) included, at \(price) per credit. No spending limit is set, so extra credits are billed until the cycle resets on \(date).")
                }
            }
            head = AdminUsageAlert(tone: .warning,
                                   title: String(localized: "You're using extra credits: \(amount) so far"), body: body)
        } else {
            head = AdminUsageAlert(
                tone: .warning,
                title: String(localized: "Your company is using extra credits"),
                body: String(localized: "\(extra) credits past the \(included) included this cycle. Replies work as usual."))
        }
        var result = head
        result.actions = [limit(f), upgrade(f)].compactMap { $0 }
        return result
    }

    private static func cycleCapped(_ f: AdminUsageFacts) -> AdminUsageAlert {
        let date = f.reset
        let head: AdminUsageAlert
        if f.textOwner {
            var body: String?
            if let capAmount = f.capAmount {
                let cap = f.money(capAmount)
                body = String(localized: "Your limit of \(cap) is reached, so nothing more is billed this cycle. Until the cycle resets on \(date), AriA answers with a lighter model. Raise the limit to go back to the standard model.")
            }
            head = AdminUsageAlert(tone: .critical,
                                   title: String(localized: "Spending limit reached: replies use a lighter model"), body: body)
        } else {
            head = AdminUsageAlert(tone: .critical,
                                   title: String(localized: "Replies use a lighter model until \(date)"),
                                   body: String(localized: "Your company reached its spending limit. An owner can raise it."))
        }
        var result = head
        result.actions = [changeLimit(f), upgrade(f)].compactMap { $0 }
        return result
    }

    /// "At this pace it will use about … extra credits by …": solo con una proiezione che supera i crediti inclusi.
    private static func projectedMemberBody(_ f: AdminUsageFacts, _ projection: AriaUsageProjection?) -> String? {
        guard let projection, let over = projection.overageCredits, over > 0, let date = f.day(projection.until) else { return nil }
        let extra = f.credits(over)
        return String(localized: "At this pace it will use about \(extra) extra credits by \(date). Owners have been notified.")
    }
}

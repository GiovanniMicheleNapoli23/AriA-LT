//
//  AdminUsageAlertBuilder+Cap.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il caso 3 dell'avviso: il tetto di spesa raggiunto (su un piano che si ferma) o vicino. Mai senza un piano assegnato.
//  Le parole del giorno o del ciclo vengono da `allowance.mode`; finché il saldo non è letto si mostra il solo titolo.
//

import Foundation

nonisolated extension AdminUsageAlertBuilder {
    static func capAlert(_ f: AdminUsageFacts) -> AdminUsageAlert? {
        if f.noPlan { return nil }
        let period = f.stopPeriod
        let capText = f.capText
        let date = f.reset
        if f.stop, f.dashboard.state == .capped || f.capState == .reached {
            let title = String(localized: "Monthly spending limit reached")
            guard f.owner else {
                return AdminUsageAlert(
                    tone: .critical, title: title,
                    body: String(localized: "Until \(date), usage past the included credits stops. An owner can raise the limit."))
            }
            var body: String?
            if let period {
                if let cap = capText {
                    body = period == .day
                        ? String(localized: "Your limit of \(cap) is reached, so nothing more is billed this cycle. Until \(date), usage past each day's included credits stops. Usage within the daily credits still works.")
                        : String(localized: "Your limit of \(cap) is reached, so nothing more is billed this cycle. Until \(date), usage past the included credits stops. Usage within the included credits still works.")
                } else {
                    // Un titolare senza euro da scrivere: la frase della scheda del tetto, senza importi.
                    body = period == .day
                        ? String(localized: "Until \(date), usage past each day's included credits stops. Usage within the daily credits still works. Raise the limit to resume right away.")
                        : String(localized: "Until \(date), usage past the included credits stops. Usage within the included credits still works. Raise the limit to resume right away.")
                }
            }
            return AdminUsageAlert(tone: .critical, title: title, body: body,
                                   actions: [raiseLimit(f), upgrade(f)].compactMap { $0 })
        }
        // Vicino al tetto: porta gli euro, quindi solo un titolare che vede i soldi.
        guard f.textOwner, f.capState == .warned, f.dashboard.state != .capped,
              let cap = capText, let billed = f.capBilled, let percent = f.capPct else { return nil }
        let pct = f.whole(percent)
        let amount = f.amount(billed)
        let title = f.elide(String(localized: "You've used \(pct)% of your spending limit: \(amount) of \(cap)"))
        let body: String?
        if !f.stop {
            body = String(localized: "At \(cap), AriA switches to a lighter model and nothing more is billed.")
        } else if let period {
            body = period == .day
                ? String(localized: "At \(cap), usage past each day's included credits stops until the cycle resets on \(date).")
                : String(localized: "At \(cap), usage past the included credits stops until the cycle resets on \(date).")
        } else {
            body = nil
        }
        return AdminUsageAlert(tone: .warning, title: title, body: body,
                               actions: [changeLimit(f), upgrade(f)].compactMap { $0 })
    }
}

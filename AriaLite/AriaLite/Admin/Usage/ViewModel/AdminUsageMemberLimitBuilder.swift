//
//  AdminUsageMemberLimitBuilder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda del tetto di un membro (contratto 3.9, `MemberSpendCapCard` della web) e la nota in fondo alla pagina.
//  Solo il ciclo corrente e solo se `dashboard.spend_cap` non è `null`: niente usato, niente prezzo, niente storico.
//

import Foundation

nonisolated enum AdminUsageMemberLimitBuilder {
    /// La scheda; `nil` per un titolare (ha i controlli di fatturazione), su un ciclo chiuso, senza tetto o senza importo.
    static func card(_ f: AdminUsageFacts) -> AdminUsageMemberLimit? {
        guard !f.owner, !f.closed, let cap = f.dashboard.spendCap, let amount = cap.amount else { return nil }
        let reached = cap.status == .reached
        var reachedNote: String?
        if reached, f.stop, let date = f.day(AdminUsageFormat.nextDay(f.end)) {
            reachedNote = String(localized: "Until \(date), usage past the included credits stops. An owner can raise the limit.")
        }
        var credits: String?
        if let equivalent = cap.creditsEquivalent {
            let figure = AdminUsageFormat.whole(equivalent, locale: f.locale)
            credits = String(localized: "= \(figure) credits")
        }
        return AdminUsageMemberLimit(
            title: String(localized: "usage.spendCap.title", defaultValue: "Spending limit"),
            amount: f.money(amount), creditsEquivalent: credits,
            chip: reached ? String(localized: "usage.spendCap.reached", defaultValue: "Reached") : String(localized: "usage.spendCap.inForce", defaultValue: "In force"), isReached: reached,
            warnedNote: cap.status == .warned ? String(localized: "Your company is close to this limit.") : nil,
            reachedNote: reachedNote,
            managedNote: String(localized: "Only owners can change this limit."))
    }

    /// "Amounts in EUR, the spending limit and usage notices are managed by owners.": sotto tutto, su ogni ciclo, a chi non è titolare.
    static func footerNote(_ f: AdminUsageFacts) -> String? {
        f.owner ? nil : String(localized: "Amounts in EUR, the spending limit and usage notices are managed by owners.")
    }
}

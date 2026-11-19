//
//  AdminUsageLiveTalkBuilder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Talk with Aria" (contratto 3.8, `live-talk-card.tsx` della web): i minuti del ciclo se il piano li ha;
//  su un ciclo chiuso "—" (i minuti di un ciclo passato non si servono); bloccata se il piano non li ha e un altro sì
//  (il piano di rango più basso che li include, con i suoi minuti, dalla config: mai un numero scritto qui).
//

import Foundation

nonisolated enum AdminUsageLiveTalkBuilder {
    static var title: String { String(localized: "usage.liveTalk.title", defaultValue: "Talk with Aria") }

    static func state(_ f: AdminUsageFacts, allowance: AriaAllowance?, phase: AdminUsagePhase) -> AdminUsageLiveTalkState {
        let minutes = allowance?.liveTalk
        let lowest = f.config.firstLiveTalkTier
        let included = minutes != nil || f.config.ownTier?.liveTalk == true
        if !included {
            guard let lowest else { return .hidden }
            return .ready(locked(f, lowest))
        }
        if f.closed { return .ready(closed(f)) }
        if let minutes, let card = open(f, minutes) { return .ready(card) }
        // Il piano lo ha ma i minuti non si leggono: nessuna cifra invece di una sbagliata.
        return allowance == nil && phase != .failed ? .loading : .hidden
    }

    private static func open(_ f: AdminUsageFacts, _ minutes: AriaUsageLiveTalk) -> AdminUsageLiveTalkCard? {
        guard let used = minutes.usedMinutes, let included = minutes.includedMinutes else { return nil }
        let usedText = AdminUsageFormat.whole(used, locale: f.locale)
        let cap = AdminUsageFormat.whole(included, locale: f.locale)
        var fraction = 0.0
        if included > 0 { fraction = min(1, NSDecimalNumber(decimal: used / included).doubleValue) }
        return AdminUsageLiveTalkCard(
            kind: .open, title: title, value: String(localized: "\(usedText) of \(cap) minutes"), fraction: max(0, fraction),
            note: String(localized: "This cycle. Past the minutes, the conversation continues as text chat."))
    }

    private static func closed(_ f: AdminUsageFacts) -> AdminUsageLiveTalkCard {
        let month = f.monthName
        return AdminUsageLiveTalkCard(kind: .closed, title: title, value: "—", note: String(localized: "Minutes used in \(month)."))
    }

    private static func locked(_ f: AdminUsageFacts, _ lowest: AriaUsageTier) -> AdminUsageLiveTalkCard {
        let plan = AdminUsageWords.planName(lowest.key)
        var card = AdminUsageLiveTalkCard(kind: .locked, title: title,
                                          lockedChip: String(localized: "usage.liveTalk.locked", defaultValue: "Not in your plan"))
        if let count = lowest.liveTalkMinutesPerCycle {
            let minutes = AdminUsageFormat.whole(count, locale: f.locale)
            card.note = String(localized: "Included from \(plan): \(minutes) minutes a month for the company.")
        }
        if f.owner {
            if f.trial != nil {
                let label = String(localized: "Choose a plan")
                card.action = AdminUsageMail.action(label: label, subject: label, email: f.email)
            } else {
                card.action = AdminUsageMail.action(label: String(localized: "Upgrade to \(plan)"),
                                                    subject: String(localized: "AriA plan request: \(plan)"), email: f.email)
            }
        } else {
            card.memberNote = String(localized: "Ask an owner to change plan.")
        }
        return card
    }
}

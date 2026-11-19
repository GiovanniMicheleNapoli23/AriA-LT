//
//  AriaUsageConfig+Tiers.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Cosa si ricava dalla lista dei piani: il piano dell'azienda, il bersaglio di "Upgrade to {plan}" (regola di
//  `upgradeTarget` nella web) e il primo piano con Live Talk. Funzioni pure: nessuna cifra nuova, solo il confronto
//  che il contratto lascia all'app.
//

import Foundation

nonisolated extension AriaUsageConfig {
    /// Il piano dell'azienda nella lista (`config.tiers[config.plan.tier]`).
    var ownTier: AriaUsageTier? {
        guard let key = plan?.tier else { return nil }
        return tiers.first { $0.key == key }
    }

    /// Il primo piano di rango più alto che include più crediti al giorno di quelli del periodo (Basic → Basic Plus →
    /// Professional). Un piano che non ne include di più non è un bersaglio: `nil` se non c'è. La quota dell'azienda è
    /// quella del periodo, che conta già gli utenti fatturati.
    func upgradeTarget(period: AriaAllowance.Period?) -> AriaUsageTier? {
        guard let period, let own = ownTier, let ownRank = own.rank else { return nil }
        let days = (period.includedDays ?? 0) > 0 ? period.includedDays : nil
        let ownDaily: Decimal?
        if period.mode == "day", let todayIncluded = period.todayIncluded {
            ownDaily = todayIncluded
        } else if let included = period.included, let days {
            ownDaily = included / Decimal(days)
        } else {
            ownDaily = own.dailyCredits(overDays: nil)
        }
        guard let ownDaily else { return nil }
        return tiers.first { tier in
            guard let rank = tier.rank, rank > ownRank, let daily = tier.dailyCredits(overDays: days) else { return false }
            return daily > ownDaily
        }
    }

    /// Il piano di rango più basso che include Live Talk, per "Included from {plan}".
    var firstLiveTalkTier: AriaUsageTier? { tiers.first { $0.liveTalk } }
}

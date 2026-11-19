//
//  AriaUsageTier.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Un piano della lista `tiers` di GET /v1/usage/config: serve a "Upgrade to {plan}" (il primo piano di rango più alto
//  che include più crediti, come `upgradeTarget` della web) e a Live Talk (il primo piano che lo include). Lettura
//  tollerante: un piano illeggibile si scarta, un campo illeggibile vale `nil`.
//

import Foundation

nonisolated struct AriaUsageTier: Decodable, Sendable, Equatable {
    /// La chiave del piano (`basic`, `professional`…): quella che `plan.tier` e `unlock_tier` nominano.
    var key: String
    var rank: Int?
    /// È il piano dell'azienda.
    var current = false
    var includedUsers: Int?
    /// Crediti al giorno (per utente se `creditsScaleWithUsers`); `nil` su un pool.
    var creditsPerDay: Decimal?
    var creditsScaleWithUsers = false
    var creditPoolPerCycle: Decimal?
    /// Il piano include Live Talk.
    var liveTalk = false
    var liveTalkMinutesPerCycle: Decimal?

    private enum CodingKeys: String, CodingKey {
        case key, rank, current, liveTalk = "live_talk"
        case includedUsers = "included_users", creditsPerDay = "credits_per_day"
        case creditsScaleWithUsers = "credits_scale_with_users", creditPoolPerCycle = "credit_pool_per_cycle"
        case liveTalkMinutesPerCycle = "live_talk_minutes_per_cycle"
    }

    init(key: String, rank: Int? = nil, current: Bool = false, includedUsers: Int? = nil, creditsPerDay: Decimal? = nil,
         creditsScaleWithUsers: Bool = false, creditPoolPerCycle: Decimal? = nil, liveTalk: Bool = false,
         liveTalkMinutesPerCycle: Decimal? = nil) {
        self.key = key
        self.rank = rank
        self.current = current
        self.includedUsers = includedUsers
        self.creditsPerDay = creditsPerDay
        self.creditsScaleWithUsers = creditsScaleWithUsers
        self.creditPoolPerCycle = creditPoolPerCycle
        self.liveTalk = liveTalk
        self.liveTalkMinutesPerCycle = liveTalkMinutesPerCycle
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Nella mappa la chiave è quella del dizionario; `readList` la mette se il piano non la ripete.
        key = c.ariaLenient(.key) ?? ""
        rank = c.ariaWhole(.rank)
        current = c.ariaLenient(.current) ?? false
        includedUsers = c.ariaWhole(.includedUsers)
        creditsPerDay = c.ariaDecimal(.creditsPerDay)
        creditsScaleWithUsers = c.ariaLenient(.creditsScaleWithUsers) ?? false
        creditPoolPerCycle = c.ariaDecimal(.creditPoolPerCycle)
        liveTalk = c.ariaLenient(.liveTalk) ?? false
        liveTalkMinutesPerCycle = c.ariaDecimal(.liveTalkMinutesPerCycle)
    }

    /// I crediti al giorno che il piano include (`dailyCredits` della web): un pool si spalma sui giorni del periodo
    /// (`nil` senza giorni), un piano per utente moltiplica per gli utenti inclusi.
    func dailyCredits(overDays days: Int?) -> Decimal? {
        if let pool = creditPoolPerCycle {
            guard let days, days > 0 else { return nil }
            return pool / Decimal(days)
        }
        guard let perDay = creditsPerDay else { return nil }
        return creditsScaleWithUsers ? perDay * Decimal(includedUsers ?? 1) : perDay
    }

    /// Legge `tiers` in ordine di rango. Il server manda una mappa chiave → piano (la web la legge così); si accetta
    /// anche un array di piani con la loro `key`. Qualsiasi altra forma, o `null`, dà una lista vuota.
    static func readList<K: CodingKey>(_ container: KeyedDecodingContainer<K>, _ key: K) -> [AriaUsageTier] {
        var found: [AriaUsageTier] = []
        if let map = container.ariaLenient([String: AriaLenient<AriaUsageTier>].self, key) {
            for (name, entry) in map {
                guard var tier = entry.value else { continue }
                if tier.key.isEmpty { tier.key = name }
                found.append(tier)
            }
        } else if let list = container.ariaLenient([AriaLenient<AriaUsageTier>].self, key) {
            found = list.compactMap(\.value)
        }
        return found.filter { !$0.key.isEmpty }.sorted {
            switch ($0.rank, $1.rank) {
            case let (a?, b?) where a != b: a < b
            case (_?, nil): true
            case (nil, _?): false
            default: $0.key < $1.key
            }
        }
    }
}

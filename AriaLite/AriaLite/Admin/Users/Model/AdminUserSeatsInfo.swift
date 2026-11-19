//
//  AdminUserSeatsInfo.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il tetto di utenti del piano (GET /v1/companies/{id}/seats, camelCase), per il pannello dei titolari (§6.4).
//  I soldi arrivano come stringhe decimali; `nil` per chi non li può vedere: si nascondono, mai 0.
//

import Foundation

nonisolated struct AdminUserSeatsInfo: Decodable, Sendable, Equatable {
    nonisolated struct NextPlan: Sendable, Equatable {
        var planKey: String
        var price: String?
        var includedUsers: Int?
    }

    var users: Int
    var pendingInvites: Int
    var includedUsers: Int?
    /// Il tetto in vigore; `nil` senza tetto.
    var userCap: Int?
    /// `hard`, `soft` o `contract`.
    var mode: String
    var overIncluded: Bool
    var requiredPlan: String?
    var planKey: String?
    var overrideActive: Bool
    var trial: Bool
    /// Diverso da `assignment`: nessun piano assegnato.
    var tierSource: String?
    var currency: String?
    var perUserPrice: String?
    var billedAmount: String?
    var next: NextPlan?

    init(users: Int = 0, pendingInvites: Int = 0, includedUsers: Int? = nil, userCap: Int? = nil, mode: String = "hard",
         overIncluded: Bool = false, requiredPlan: String? = nil, planKey: String? = nil, overrideActive: Bool = false,
         trial: Bool = false, tierSource: String? = "assignment", currency: String? = nil, perUserPrice: String? = nil,
         billedAmount: String? = nil, next: NextPlan? = nil) {
        self.users = users
        self.pendingInvites = pendingInvites
        self.includedUsers = includedUsers
        self.userCap = userCap
        self.mode = mode
        self.overIncluded = overIncluded
        self.requiredPlan = requiredPlan
        self.planKey = planKey
        self.overrideActive = overrideActive
        self.trial = trial
        self.tierSource = tierSource
        self.currency = currency
        self.perUserPrice = perUserPrice
        self.billedAmount = billedAmount
        self.next = next
    }

    private enum CodingKeys: String, CodingKey {
        case users, pendingInvites, includedUsers, userCap, mode, overIncluded, requiredPlan, planKey, overrideActive
        case trial, tierSource, currency, perUserPrice, billedAmount, next
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func json(_ key: CodingKeys) -> AriaJSON? { try? c.decodeIfPresent(AriaJSON.self, forKey: key) }
        func int(_ key: CodingKeys) -> Int? { json(key)?.doubleValue.map { Int($0) } }
        /// Un prezzo: stringa decimale, o numero sui server che lo mandano così.
        func money(_ value: AriaJSON?) -> String? {
            if let text = value?.nonEmptyString { return text }
            return value?.doubleValue.map { String($0) }
        }
        users = int(.users) ?? 0
        pendingInvites = int(.pendingInvites) ?? 0
        includedUsers = int(.includedUsers)
        userCap = int(.userCap)
        mode = json(.mode)?.nonEmptyString ?? "hard"
        overIncluded = json(.overIncluded)?.boolValue ?? false
        requiredPlan = json(.requiredPlan)?.nonEmptyString
        planKey = json(.planKey)?.nonEmptyString
        overrideActive = json(.overrideActive)?.boolValue ?? false
        trial = json(.trial)?.boolValue ?? false
        tierSource = json(.tierSource)?.nonEmptyString
        currency = json(.currency)?.nonEmptyString
        perUserPrice = money(json(.perUserPrice))
        billedAmount = money(json(.billedAmount))
        if let next = json(.next), let key = next["planKey"]?.nonEmptyString {
            self.next = NextPlan(planKey: key, price: money(next["price"]),
                                 includedUsers: next["includedUsers"]?.doubleValue.map { Int($0) })
        }
    }

    /// I posti presi: utenti più inviti aperti.
    var taken: Int { users + pendingInvites }
}

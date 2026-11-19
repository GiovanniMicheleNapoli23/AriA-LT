//
//  AdminUsageBillingTestSupport.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Gli scenari dei controlli di fatturazione dei titolari (contratto 5): la scheda del limite con alcune chiavi sostituite,
//  i fatti con il limite letto dal saldo e le righe dello storico, dei membri e delle regole degli avvisi. Nessuna rete.
//

import Foundation
import Testing
@testable import AriaLite

extension UsageFixture {
    /// La scheda del tetto del contratto con alcune chiavi sostituite (`NSNull()` per un `null`, `nil` per toglierle).
    static func capView(_ replacing: [String: Any?] = [:]) throws -> AriaSpendCapView {
        var root = try #require(JSONSerialization.jsonObject(with: Data(spendCapJSON.utf8)) as? [String: Any])
        for (key, value) in replacing {
            if let value { root[key] = value } else { root.removeValue(forKey: key) }
        }
        return try JSONDecoder().decode(AriaSpendCapView.self, from: JSONSerialization.data(withJSONObject: root))
    }

    /// Un titolare su un piano che si ferma al limite (`adminConfigJSON`): il saldo dice com'è il limite.
    /// - `state`: lo stato del limite per il saldo; `billed`: gli euro addebitati (`nil` = non noti).
    /// - `percent`: la quota che manda il cruscotto.
    static func limitFacts(state: String = "ok", amount: String? = "500", billed: String? = "410", percent: Int? = 82,
                           readAllowance: Bool = true, degrade: Bool = false, config: [String: Any?] = [:],
                           period: [String: Any] = [:], allowanceTop: [String: Any] = [:]) throws -> AdminUsageFacts {
        var configTop = config
        if degrade && !configTop.keys.contains("overage") { configTop["overage"] = degradeOverage }
        let board = try adminDashboard(period: period, top: ["spend_cap": dashboardCap(state, percent: percent)])
        var allowance: AriaAllowance?
        if readAllowance {
            allowance = try adminAllowance(spendCap: cap(state, amount: amount, billed: billed), top: allowanceTop)
        }
        return try adminFacts(dashboard: board, config: adminConfig(replacing: configTop), allowance: allowance)
    }

    /// Le righe dello storico del contratto.
    static func history(_ json: String = spendCapHistoryJSON) throws -> [AriaSpendCapChange] {
        try decode([AriaSpendCapChange].self, json)
    }

    /// I membri attivi: Giulia (titolare, sempre avvisata), Marco (aggiunto) e Elena (si può aggiungere).
    static func members(_ json: String = recipientsJSON) throws -> [AriaNoticeRecipients.Member] {
        try decode(AriaNoticeRecipients.self, json).members
    }

    static let elena = """
    { "user_id": "6720a1f0c2d94e0012ab34e9", "email": "elena@example.com", "name": "Elena Rossi", "role": "member", "default": false, "added": false }
    """

    static let fiveMembersJSON = """
    {
      "user_ids": ["6720a1f0c2d94e0012ab34d2"], "default_roles": ["owner"],
      "members": [
        { "user_id": "6720a1f0c2d94e0012ab34cd", "email": "giulia@example.com", "name": "Giulia Ferri", "role": "owner", "default": true, "added": false },
        { "user_id": "6720a1f0c2d94e0012ab34d2", "email": "marco@example.com", "name": "Marco Bianchi", "role": "member", "default": false, "added": true },
        \(UsageFixture.elena)
      ]
    }
    """

    static let giuliaId = "6720a1f0c2d94e0012ab34cd"
    static let marcoId = "6720a1f0c2d94e0012ab34d2"
    static let elenaId = "6720a1f0c2d94e0012ab34e9"
}

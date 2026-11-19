//
//  AdminUsageFixtures.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Gli scenari della pagina Usage: config di un titolare e di un membro, cruscotto e saldo con alcune chiavi
//  sostituite, e i fatti già pronti. Si parte dagli esempi JSON del contratto; nessuna rete.
//

import Foundation
import Testing
@testable import AriaLite

extension UsageFixture {
    /// La config di un titolare su Professional che vede i soldi (contratto 3.1 e crediti 3.3).
    static let adminConfigJSON = """
    {
      "currency": "EUR", "tier_source": "assignment", "amounts_visible": true, "can_manage_plan": true,
      "plan": { "tier": "professional", "credits_per_day": 25, "credits_scale_with_users": true },
      "billing": { "customer_visibility": true },
      "overage": { "price_per_credit": "0.16", "at_spend_cap": "stop", "spend_cap_default_eur": null },
      "ui": { "sales_contact_email": "sales@example.test", "projection_window_days": 7 },
      "notifications": { "email_enabled": true },
      "tiers": {
        "basic": { "key": "basic", "rank": 1, "included_users": 1, "credits_per_day": 40, "credits_scale_with_users": true,
                   "live_talk": false },
        "basic_plus": { "key": "basic_plus", "rank": 2, "included_users": 3, "credits_per_day": 25, "credits_scale_with_users": true,
                        "live_talk": false },
        "professional": { "key": "professional", "rank": 3, "current": true, "included_users": 7, "credits_per_day": 25,
                          "credits_scale_with_users": true, "live_talk": true, "live_talk_minutes_per_cycle": 120 },
        "enterprise": { "key": "enterprise", "rank": 4, "credit_pool_per_cycle": 9000, "live_talk": true,
                        "live_talk_minutes_per_cycle": 600 }
      }
    }
    """

    /// La config con alcune chiavi di primo livello sostituite (`NSNull()` per un `null`, `nil` per toglierle).
    static func adminConfig(replacing top: [String: Any?] = [:]) throws -> AriaUsageConfig {
        var root = try #require(JSONSerialization.jsonObject(with: Data(adminConfigJSON.utf8)) as? [String: Any])
        for (key, value) in top {
            if let value { root[key] = value } else { root.removeValue(forKey: key) }
        }
        return try JSONDecoder().decode(AriaUsageConfig.self, from: JSONSerialization.data(withJSONObject: root))
    }

    /// La config di un membro: niente euro, niente piano da gestire.
    static func memberAdminConfig(replacing top: [String: Any?] = [:]) throws -> AriaUsageConfig {
        var all: [String: Any?] = ["can_manage_plan": false, "amounts_visible": false]
        all.merge(top) { _, new in new }
        return try adminConfig(replacing: all)
    }

    /// Il cruscotto del contratto con chiavi di primo livello e del `period` sostituite.
    static func adminDashboard(period: [String: Any] = [:], top: [String: Any?] = [:]) throws -> AriaUsageDashboard {
        var root = try #require(JSONSerialization.jsonObject(with: Data(dashboardJSON.utf8)) as? [String: Any])
        var periodObject = try #require(root["period"] as? [String: Any])
        periodObject.merge(period) { _, new in new }
        root["period"] = periodObject
        for (key, value) in top {
            if let value { root[key] = value } else { root.removeValue(forKey: key) }
        }
        return try JSONDecoder().decode(AriaUsageDashboard.self, from: JSONSerialization.data(withJSONObject: root))
    }

    /// Il saldo di un titolare che vede i soldi: modo `daily`, nessun tetto. `top` sostituisce chiavi di primo livello.
    static func adminAllowance(spendCap: [String: Any]? = nil, top: [String: Any] = [:]) throws -> AriaAllowance {
        var all: [String: Any] = ["amounts_visible": true, "tier": "professional",
                                  "spend_cap": spendCap ?? NSNull()]
        all.merge(top) { _, new in new }
        return try allowance(top: all)
    }

    /// I fatti, in inglese americano.
    static func adminFacts(dashboard: AriaUsageDashboard? = nil, config: AriaUsageConfig? = nil,
                           allowance: AriaAllowance? = nil) throws -> AdminUsageFacts {
        let board = try dashboard ?? adminDashboard()
        let cfg = try config ?? adminConfig()
        return try #require(AdminUsageFacts(dashboard: board, config: cfg, allowance: allowance, locale: english))
    }

    /// Il cruscotto di un membro: niente euro, solo la propria riga e nessun elenco di agenti.
    static func memberDashboard(period: [String: Any] = [:], top: [String: Any?] = [:]) throws -> AriaUsageDashboard {
        var all: [String: Any?] = ["amounts_visible": false, "by_agent": NSNull()]
        all.merge(top) { _, new in new }
        return try adminDashboard(period: period, top: all)
    }

    /// L'avviso che apre la pagina per questi dati.
    static func adminAlert(_ board: AriaUsageDashboard? = nil, config: AriaUsageConfig? = nil,
                           allowance: AriaAllowance? = nil) throws -> AdminUsageAlert? {
        AdminUsageAlertBuilder.build(try adminFacts(dashboard: board, config: config, allowance: allowance))
    }

    /// Il piano che al tetto degrada invece di fermarsi.
    static var degradeOverage: [String: Any] {
        ["price_per_credit": "0.16", "at_spend_cap": "degrade", "spend_cap_default_eur": NSNull()]
    }

    /// Una prova che finisce il 24 novembre, senza utenti fatturati e con lo stato "ok".
    static var trialTop: [String: Any?] {
        ["trial": ["starts_on": "2026-11-10", "ends_on": "2026-11-24", "days_left": 6], "state": "ok",
         "per_user_credits": NSNull(), "billed_users": NSNull()]
    }

    /// Una proiezione che resta dentro gli inclusi.
    static var withinProjection: [String: Any] {
        ["until": "2026-11-30", "days_left": 12, "window_days": 7, "daily_average": "100", "projected": "3000",
         "overage_credits": "0", "overage_amount": "0"]
    }

    /// Il tetto come lo dice il saldo.
    static func cap(_ state: String, amount: String? = "500", billed: String? = "410") -> [String: Any] {
        ["state": state, "amount": amount.map { $0 as Any } ?? NSNull(), "billed": billed.map { $0 as Any } ?? NSNull()]
    }

    /// Il tetto come lo legge il cruscotto di ognuno.
    static func dashboardCap(_ status: String, percent: Int? = 82) -> [String: Any] {
        ["amount": "500", "credits_equivalent": "3125", "billed": "410", "billed_credits": "2562",
         "percent": percent.map { $0 as Any } ?? NSNull(), "status": status]
    }
}


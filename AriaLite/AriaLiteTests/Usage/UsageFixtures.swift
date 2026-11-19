//
//  UsageFixtures.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Payload di prova dei crediti (config, saldo, evento di una risposta) e piccoli aiuti per i test puri.
//

import Foundation
import Testing
@testable import AriaLite

enum UsageFixture {
    static let english = Locale(identifier: "en_US")
    static let italian = Locale(identifier: "it_IT")

    /// Un decimale esatto da testo: i letterali `1.1` di Swift passano da `Double` e non sono esatti.
    static func d(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
    }

    static func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    static func json(_ text: String) throws -> AriaJSON {
        try JSONDecoder().decode(AriaJSON.self, from: Data(text.utf8))
    }

    /// Il 18 novembre 2026, ore 22:14:02 UTC.
    static let now = AriaDate.parse("2026-11-18T22:14:02Z")!

    /// L'esempio del contratto (membro, piano Basic).
    static let memberConfig = """
    {
      "currency": "EUR", "tier_source": "assignment", "amounts_visible": false, "can_manage_plan": false,
      "plan": { "tier": "basic", "credits_per_day": 40, "credits_scale_with_users": true, "credit_pool_per_cycle": null },
      "effort": {
        "default_level": "base",
        "enabled_actions": ["chat.reply", "rag.diagnostic", "workflow.step"],
        "levels": {
          "max":    { "multiplier": "6.3", "available": false, "warning": true,  "unlock_tier": "enterprise" },
          "base":   { "multiplier": "1.0", "available": true,  "warning": false, "unlock_tier": null },
          "extra":  { "multiplier": "3.7", "available": false, "warning": true,  "unlock_tier": "professional" },
          "medium": { "multiplier": "1.7", "available": false, "warning": false, "unlock_tier": "professional" },
          "high":   { "multiplier": "2.4", "available": false, "warning": false, "unlock_tier": "professional" },
          "ultra":  { "multiplier": "9.9", "available": true }
        }
      },
      "actions": {
        "chat.reply":     { "action_type": "chat.reply",     "credit_weight": "1.0", "upgrade_tier": null, "background_offer": false },
        "rag.diagnostic": { "action_type": "rag.diagnostic", "credit_weight": "1.1", "upgrade_tier": null, "background_offer": false }
      },
      "charge_rounding_increment": "0.1",
      "ui": { "credit_window_hours": 24, "credit_note_mode": "always", "sales_contact_email": "sales@example.test" },
      "billing": { "customer_visibility": true },
      "overage": { "at_spend_cap": "stop" },
      "trial": null, "tiers": [], "warning_shares": [0.7]
    }
    """

    static func config(_ json: String = memberConfig) throws -> AriaUsageConfig {
        try decode(AriaUsageConfig.self, json)
    }

    /// Una config con tutti i livelli selezionabili e 172.8 crediti al giorno (172.8 ÷ 2.4 = 72 risposte).
    static func openConfig(creditsPerDay: String? = "\"172.8\"", increment: String? = "\"0.1\"") throws -> AriaUsageConfig {
        try config("""
        {
          "plan": { "tier": "professional", "credits_per_day": \(creditsPerDay ?? "null") },
          "effort": { "default_level": "base", "enabled_actions": ["chat.reply"],
            "levels": {
              "base": { "multiplier": "1.0", "available": true },
              "high": { "multiplier": "2.4", "available": true, "warning": false } } },
          "actions": { "chat.reply": { "credit_weight": "1.0" } },
          "charge_rounding_increment": \(increment ?? "null")
        }
        """)
    }

    /// Il saldo di un piano giornaliero (esempio del contratto). Ogni parametro sostituisce alcune chiavi del livello
    /// indicato (`NSNull()` per un `null`), così nessun JSON ha chiavi doppie.
    static func allowance(top: [String: Any] = [:], period: [String: Any] = [:], window: [String: Any] = [:],
                          noWindow: Bool = false) throws -> AriaAllowance {
        var root = try #require(JSONSerialization.jsonObject(with: Data(baseAllowance.utf8)) as? [String: Any])
        root.merge(top) { _, new in new }
        // Un blocco sostituito da `top` (per esempio `"period": NSNull()`) non si fonde più.
        if var periodObject = root["period"] as? [String: Any] {
            periodObject.merge(period) { _, new in new }
            root["period"] = periodObject
        }
        if noWindow {
            root["window"] = NSNull()
        } else if var windowObject = root["window"] as? [String: Any] {
            windowObject.merge(window) { _, new in new }
            root["window"] = windowObject
        }
        return try JSONDecoder().decode(AriaAllowance.self, from: JSONSerialization.data(withJSONObject: root))
    }

    static let baseAllowance = """
    {
      "enabled": true, "tier": "basic", "tier_source": "assignment", "currency": "EUR",
      "amounts_visible": false, "mode": "daily", "state": "ok",
      "window": { "hours": 24, "daily_allowance": "40", "consumed": "12.4", "available": "27.6",
                  "next_refill_at": "2026-11-19T08:14:02Z", "billed_users": 1, "per_user_credits": 40 },
      "period": { "mode": "cycle", "start": "2026-11-01", "end": "2026-11-30", "closed": false, "basis": "max",
                  "included": "1200", "included_days": 30, "credits_used": "9.2", "token_equivalent": "41.6",
                  "consumed": "41.6", "pct": "0.035", "overage_credits": "0", "overage_amount": null,
                  "price_per_credit": null, "extra_credits_billable": true, "resets_at": "2026-12-01T00:00:00Z",
                  "today_included": null, "today_consumed": null, "today_overage_credits": null,
                  "today_overage_amount": null },
      "today": { "credits": "12.4" },
      "meters": {
        "today": { "used": "12.4", "included": "40", "percent": 31, "resets_at": "2026-11-19T00:00:00Z", "warn_threshold": "0.80" },
        "week":  { "used": "20.5", "included": "280", "percent": 7, "resets_at": "2026-11-23T00:00:00Z" } },
      "last_days": [ { "day": "2026-11-12", "credits": "0" }, { "day": "2026-11-18", "credits": "12.4" } ],
      "projection": null, "notice_thresholds": ["0.70", "1.00"], "trial": null, "spend_cap": null,
      "storage": null, "live_talk": null
    }
    """
}

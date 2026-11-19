//
//  UsageBillingFixtures.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Gli esempi JSON del contratto della sezione Usage (cruscotto, tetto, storico, destinatari, regole degli avvisi) e
//  due piccoli aiuti: modificare un JSON e scrivere un body come testo con le chiavi in ordine.
//

import Foundation
import Testing
@testable import AriaLite

extension UsageFixture {
    /// Il cruscotto di un titolare su un piano per utente (contratto, 3.1).
    static let dashboardJSON = """
    {
      "enabled": true, "tier": "professional", "tier_source": "assignment", "currency": "EUR",
      "amounts_visible": true, "mode": "daily", "state": "notice",
      "period": {
        "mode": "cycle", "start": "2026-11-01", "end": "2026-11-30", "closed": false,
        "basis": "max", "included": "5250", "included_days": 30,
        "credits_used": "3015.0", "token_equivalent": "3832.5", "consumed": "3832.5", "pct": "0.73",
        "overage_credits": "0", "overage_amount": "0", "price_per_credit": "0.16",
        "extra_credits_billable": true, "resets_at": "2026-12-01T00:00:00Z",
        "today_included": null, "today_consumed": null,
        "today_overage_credits": null, "today_overage_amount": null
      },
      "today": { "credits": "38.4" },
      "week": { "used": "412.5", "included": "1225", "percent": 33, "resets_at": "2026-11-23T00:00:00Z" },
      "spend_cap": { "amount": "500", "credits_equivalent": "3125", "billed": "0", "billed_credits": "0", "percent": 0, "status": "ok" },
      "series": [
        { "day": "2026-11-01", "credits": "96.0", "token_equivalent": "131.2", "consumed": "131.2", "in_period": true },
        { "day": "2026-11-18", "credits": "31.0", "token_equivalent": "38.4", "consumed": "38.4", "in_period": true }
      ],
      "by_action_type": [
        { "key": "chat.reply", "label": null, "credits": "2140.5", "actions": 1712, "share": "0.71" },
        { "key": "rag.diagnostic", "label": null, "credits": "874.5", "actions": 795, "share": "0.29" }
      ],
      "by_user": [
        { "key": "6720a1f0c2d94e0012ab34cd", "label": null, "credits": "1220.0", "actions": 930, "share": "0.40" }
      ],
      "by_agent": [
        { "key": "agent:general", "label": null, "credits": "2630.0", "actions": 2200, "share": "0.87" },
        { "key": "workflow:6b0c11aa90f3d90011ee7701", "label": "Weekly line report", "credits": "385.0", "actions": 307, "share": "0.13" }
      ],
      "projection": {
        "until": "2026-11-30", "days_left": 12, "window_days": 7, "daily_average": "212.9",
        "projected": "6387.3", "overage_credits": "1137.3", "overage_amount": "181.97"
      },
      "notice_thresholds": ["0.70", "1.00"],
      "trial": null,
      "billed_users": 7,
      "per_user_credits": 25,
      "cycles": [
        { "start": "2026-11-01", "end": "2026-11-30" },
        { "start": "2026-10-01", "end": "2026-10-31" }
      ]
    }
    """

    /// La scheda del tetto di spesa (5.1).
    static let spendCapJSON = """
    {
      "amount": "500", "credits_equivalent": "3125", "status": "ok", "can_edit": true,
      "currency": "EUR", "effective_from": "2026-11-03T09:12:44Z",
      "source": "tenant", "origin": "record",
      "suggestion": "1200", "minimum": "0", "warn_share": "0.80",
      "locked": null, "amounts_visible": true
    }
    """

    /// Lo storico del tetto (5.2).
    static let spendCapHistoryJSON = """
    [
      { "effective_from": "2026-11-03T09:12:44Z", "set_by": "6720a1f0c2d94e0012ab34cd", "set_by_role": "owner",
        "previous_amount": null, "amount": "500", "source": "tenant" },
      { "effective_from": "2026-10-01T00:00:00.250", "set_by": null, "set_by_role": "super_admin",
        "previous_amount": "500", "amount": null, "source": "super_admin" }
    ]
    """

    /// I destinatari degli avvisi (5.3).
    static let recipientsJSON = """
    {
      "user_ids": ["6720a1f0c2d94e0012ab34d2"],
      "default_roles": ["owner"],
      "members": [
        { "user_id": "6720a1f0c2d94e0012ab34cd", "email": "giulia@example.com", "name": "Giulia Ferri", "role": "owner", "default": true, "added": false },
        { "user_id": "6720a1f0c2d94e0012ab34d2", "email": "marco@example.com", "name": "Marco Bianchi", "role": "member", "default": false, "added": true }
      ]
    }
    """

    /// Le regole dei tre avvisi (5.4): l'azienda tiene suoi il banner e la soglia dei crediti del giorno e il
    /// `repeat` degli extra.
    static let noticeSettingsJSON = """
    {
      "daily_allowance": {
        "email":    { "platform": true,  "company": null,  "resolved": true },
        "banner":   { "platform": true,  "company": false, "resolved": false },
        "threshold":{ "platform": "0.80", "company": "0.60", "resolved": "0.60" },
        "repeat":   { "platform": null,  "company": null,  "resolved": null },
        "tenant_recipients": { "platform": ["owner"], "company": null, "resolved": ["owner"] },
        "user_ids": { "platform": null, "company": null, "resolved": null }
      },
      "cap_approaching": {
        "email":    { "platform": true,  "company": null,  "resolved": true },
        "banner":   { "platform": true,  "company": null,  "resolved": true },
        "threshold":{ "platform": "0.80", "company": null, "resolved": "0.80" },
        "repeat":   { "platform": "once_per_cycle",  "company": null,  "resolved": "once_per_cycle" },
        "tenant_recipients": { "platform": ["owner"], "company": null, "resolved": ["owner"] },
        "user_ids": { "platform": null, "company": null, "resolved": null }
      },
      "overage": {
        "email":    { "platform": true,  "company": null,  "resolved": true },
        "banner":   { "platform": true,  "company": null,  "resolved": true },
        "threshold":{ "platform": "1", "company": null, "resolved": "1" },
        "repeat":   { "platform": null,  "company": "once_per_week",  "resolved": "once_per_week" },
        "tenant_recipients": { "platform": ["owner"], "company": null, "resolved": ["owner"] },
        "user_ids": { "platform": null, "company": null, "resolved": null }
      }
    }
    """

    static func dashboard(_ json: String = dashboardJSON) throws -> AriaUsageDashboard {
        try decode(AriaUsageDashboard.self, json)
    }

    static func noticeSettings(_ json: String = noticeSettingsJSON) throws -> AriaNoticeSettings {
        try decode(AriaNoticeSettings.self, json)
    }

    /// Il cruscotto con alcune chiavi di primo livello sostituite (`NSNull()` per un `null`, `Optional.none` per toglierle).
    static func dashboard(replacing top: [String: Any?]) throws -> AriaUsageDashboard {
        var root = try #require(JSONSerialization.jsonObject(with: Data(dashboardJSON.utf8)) as? [String: Any])
        for (key, value) in top {
            if let value { root[key] = value } else { root.removeValue(forKey: key) }
        }
        return try JSONDecoder().decode(AriaUsageDashboard.self, from: JSONSerialization.data(withJSONObject: root))
    }

    /// Un body come testo con le chiavi in ordine, come lo vede il server.
    static func body(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    /// Una risposta HTTP finta per `AriaHTTP.check`.
    static func httpError(_ status: Int, _ body: String) -> AriaError? {
        let response = HTTPURLResponse(url: URL(string: "https://x.test/v1/usage/spend-cap")!, statusCode: status,
                                       httpVersion: nil, headerFields: nil)!
        do {
            try AriaHTTP.check(response, Data(body.utf8))
            return nil
        } catch {
            return error as? AriaError
        }
    }
}

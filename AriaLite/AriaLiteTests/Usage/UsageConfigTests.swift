//
//  UsageConfigTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  GET /v1/usage/config e POST /v1/usage/estimate: lettura tollerante, livelli in ordine, crediti per risposta dalla
//  config, riga di costo di un livello (stima del server o calcolo), il 402 al tetto di spesa.
//

import Foundation
import Testing
@testable import AriaLite

@Suite("Usage config")
struct UsageConfigTests {
    private func d(_ text: String) -> Decimal { UsageFixture.d(text) }

    @Test func theContractExampleDecodes() throws {
        let config = try UsageFixture.config()

        #expect(config.chatEffortEnabled)
        #expect(config.effort?.defaultLevel == .base)
        #expect(config.currency == "EUR")
        #expect(config.tierSource == "assignment")
        #expect(!config.amountsVisible)
        #expect(!config.canManagePlan)
        #expect(config.plan?.tier == "basic")
        // 40 arriva come numero JSON, non come stringa.
        #expect(config.plan?.creditsPerDay == 40)
        #expect(config.plan?.creditPoolPerCycle == nil)
        #expect(config.chargeRoundingIncrement == d("0.1"))
        #expect(config.actions["chat.reply"]?.creditWeight == d("1.0"))
        #expect(config.actions["rag.diagnostic"]?.creditWeight == d("1.1"))
        #expect(config.creditNoteMode == "always")
        #expect(config.showsCreditNote)
        #expect(config.customerVisibility)
        #expect(config.salesContactEmail == "sales@example.test")
        #expect(config.atSpendCap == "stop")
        #expect(config.trial == nil)
        #expect(!config.isOnTrial)
    }

    @Test func levelsComeInRankOrderWhateverTheKeyOrderAndUnknownKeysAreDropped() throws {
        let config = try UsageFixture.config()

        #expect(config.orderedLevels.map(\.level) == [.base, .medium, .high, .extra, .max])
        #expect(config.effort?.levels.count == 5)
    }

    @Test func levelsCarryTheirMultiplierLockAndWarning() throws {
        let config = try UsageFixture.config()
        let levels = Dictionary(uniqueKeysWithValues: config.orderedLevels.map { ($0.level, $0.info) })

        #expect(levels[.base]?.multiplier == d("1.0"))
        #expect(levels[.base]?.available == true)
        #expect(levels[.base]?.unlockTier == nil)
        #expect(levels[.high]?.multiplier == d("2.4"))
        #expect(levels[.high]?.available == false)
        #expect(levels[.high]?.warning == false)
        #expect(levels[.high]?.unlockTier == "professional")
        #expect(levels[.extra]?.warning == true)
        #expect(levels[.max]?.unlockTier == "enterprise")
    }

    @Test func effortLevelsAreComparableByRank() {
        #expect(AriaEffortLevel.allCases == [.base, .medium, .high, .extra, .max])
        #expect(AriaEffortLevel.base < .medium)
        #expect(AriaEffortLevel.high < .extra)
        #expect(AriaEffortLevel.max > .extra)
        #expect(AriaEffortLevel.allCases.sorted(by: >).first == .max)
        #expect(AriaEffortLevel.high.title == "High")
    }

    @Test func theControlExistsOnlyWhenChatReplyIsEnabled() throws {
        let without = try UsageFixture.config(#"{"effort": {"enabled_actions": ["rag.diagnostic"], "levels": {}}}"#)
        #expect(!without.chatEffortEnabled)

        let none = try UsageFixture.config("{}")
        #expect(!none.chatEffortEnabled)
        #expect(none.orderedLevels.isEmpty)
        #expect(none.effort == nil)
        #expect(none.showsCreditNote)
    }

    @Test func oneBadFieldNeverFailsThePayload() throws {
        let config = try UsageFixture.config("""
        {
          "currency": 5, "amounts_visible": "yes", "plan": "basic",
          "effort": { "default_level": "ultra", "enabled_actions": ["chat.reply"],
            "levels": { "base": { "multiplier": "1.7x", "available": true }, "medium": "broken",
                        "high": { "multiplier": 2.4, "available": "no" } } },
          "actions": { "chat.reply": { "credit_weight": "oops" }, "x": 3 },
          "charge_rounding_increment": "0,1", "ui": [], "billing": "no", "trial": "soon"
        }
        """)

        #expect(config.currency == nil)
        #expect(!config.amountsVisible)
        #expect(config.plan == nil)
        #expect(config.effort?.defaultLevel == nil)
        #expect(config.chatEffortEnabled)
        #expect(config.effort?.levels[.base]?.multiplier == nil)
        #expect(config.effort?.levels[.base]?.available == true)
        #expect(config.effort?.levels[.medium] == nil)
        // Un numero JSON vale come una stringa decimale.
        #expect(config.effort?.levels[.high]?.multiplier == d("2.4"))
        #expect(config.effort?.levels[.high]?.available == false)
        #expect(config.actions["chat.reply"]?.creditWeight == nil)
        #expect(config.actions["x"] == nil)
        #expect(config.chargeRoundingIncrement == nil)
        #expect(config.showsCreditNote)
        #expect(!config.customerVisibility)
        #expect(config.trial == nil)
    }

    @Test func theTrialIsReadAsItIsSent() throws {
        let config = try UsageFixture.config(#"{"trial": {"starts_on": "2026-11-19", "ends_on": "2026-12-03", "days_left": 15}}"#)

        #expect(config.isOnTrial)
        #expect(config.trial == AriaUsageTrial(startsOn: "2026-11-19", endsOn: "2026-12-03", daysLeft: 15))
    }

    @Test func creditNoteModeOffHidesTheNote() throws {
        let off = try UsageFixture.config(#"{"ui": {"credit_note_mode": "off"}}"#)
        let always = try UsageFixture.config(#"{"ui": {"credit_note_mode": "always"}}"#)

        #expect(!off.showsCreditNote)
        #expect(always.showsCreditNote)
    }

    // MARK: Crediti per risposta

    @Test func creditsPerReplyAreWeightTimesMultiplierRoundedUp() throws {
        let config = try UsageFixture.config()

        #expect(AriaCredits.creditsPerReply(config: config, level: .base) == d("1.0"))
        #expect(AriaCredits.creditsPerReply(config: config, level: .high) == d("2.4"))
        // 1.1 × 1.7 = 1.87 → 1.9; 1.1 × 2.4 = 2.64 → 2.7.
        #expect(AriaCredits.creditsPerReply(config: config, level: .medium, action: "rag.diagnostic") == d("1.9"))
        #expect(AriaCredits.creditsPerReply(config: config, level: .high, action: "rag.diagnostic") == d("2.7"))
    }

    @Test func creditsPerReplyAreMissingWhenAnyFigureIsMissing() throws {
        let config = try UsageFixture.config()
        #expect(AriaCredits.creditsPerReply(config: config, level: .base, action: "doc.generate") == nil)

        let noIncrement = try UsageFixture.openConfig(increment: nil)
        #expect(AriaCredits.creditsPerReply(config: noIncrement, level: .high) == nil)

        let open = try UsageFixture.openConfig()
        #expect(AriaCredits.creditsPerReply(config: open, level: .max) == nil)
        #expect(AriaCredits.creditsPerReply(config: AriaUsageConfig(), level: .base) == nil)
    }

    // MARK: Riga di costo

    @Test func withoutAnEstimateTheLineSaysUpTo() throws {
        let config = try UsageFixture.openConfig()
        let line = try #require(AriaEffortCostLine.make(config: config, level: .high, estimate: nil))

        #expect(line.credits == d("2.4"))
        #expect(line.replies == 72)
        #expect(!line.isEstimate)
        #expect(line.formatted(locale: UsageFixture.english) == "2.4 credits per reply · up to 72 a day")
    }

    @Test func withAnEstimateTheLineSaysAbout() throws {
        let config = try UsageFixture.openConfig()
        let estimate = try UsageFixture.decode(AriaUsageEstimate.self, """
        {"action_type":"chat.reply","effort_requested":"high","effort_effective":"high","degraded":false,
         "credits_each":"2.4","credits_total":"2.4","context_tokens":8000,"est_tokens_each":14000,
         "allowance_impact_each":"2.4","allowance_impact_total":"2.4"}
        """)
        let line = try #require(AriaEffortCostLine.make(config: config, level: .high, estimate: estimate))

        #expect(line.isEstimate)
        #expect(line.replies == 72)
        #expect(line.formatted(locale: UsageFixture.english) == "2.4 credits per reply · about 72 a day")
    }

    @Test func theEstimateFiguresWinOverTheComputedOnes() throws {
        let config = try UsageFixture.openConfig()
        // Il server stima 3 crediti a risposta e 4 di impatto sul saldo (conta per dimensione).
        let estimate = AriaUsageEstimate(effortEffective: "high", creditsEach: d("3"), allowanceImpactEach: d("4"))
        let line = try #require(AriaEffortCostLine.make(config: config, level: .high, estimate: estimate))

        #expect(line.credits == 3)
        #expect(line.replies == 43)
    }

    @Test func anEstimateForAnotherLevelIsTreatedAsMissing() throws {
        let config = try UsageFixture.openConfig()
        let estimate = AriaUsageEstimate(effortEffective: "base", creditsEach: d("1"), allowanceImpactEach: d("1"))
        let line = try #require(AriaEffortCostLine.make(config: config, level: .high, estimate: estimate))

        #expect(!line.isEstimate)
        #expect(line.credits == d("2.4"))
        #expect(line.formatted(locale: UsageFixture.english) == "2.4 credits per reply · up to 72 a day")
    }

    @Test func anEstimateWithUnreadableCreditsIsTreatedAsMissing() throws {
        let config = try UsageFixture.openConfig()
        let estimate = try UsageFixture.decode(AriaUsageEstimate.self,
                                               #"{"effort_effective":"high","credits_each":"2.4abc","allowance_impact_each":"2.4"}"#)
        let line = try #require(AriaEffortCostLine.make(config: config, level: .high, estimate: estimate))

        #expect(!line.isEstimate)
        #expect(line.formatted(locale: UsageFixture.english) == "2.4 credits per reply · up to 72 a day")
    }

    @Test func aPoolShowsNoRepliesPerDay() throws {
        let config = try UsageFixture.openConfig(creditsPerDay: nil)
        let line = try #require(AriaEffortCostLine.make(config: config, level: .high, estimate: nil))

        #expect(line.replies == nil)
        #expect(line.formatted(locale: UsageFixture.english) == "2.4 credits per reply")
    }

    @Test func oneCreditIsSingular() throws {
        let config = try UsageFixture.openConfig()
        let line = try #require(AriaEffortCostLine.make(config: config, level: .base, estimate: nil))

        #expect(line.formatted(locale: UsageFixture.english) == "1 credit per reply · up to 172 a day")

        let pool = try UsageFixture.openConfig(creditsPerDay: nil)
        let poolLine = try #require(AriaEffortCostLine.make(config: pool, level: .base, estimate: nil))
        #expect(poolLine.formatted(locale: UsageFixture.english) == "1 credit per reply")
    }

    @Test func noIncrementAndNoEstimateMeansNoLine() throws {
        let config = try UsageFixture.openConfig(increment: nil)

        #expect(AriaEffortCostLine.make(config: config, level: .high, estimate: nil) == nil)
        #expect(AriaEffortCostLine.make(config: config, level: .max, estimate: nil) == nil)
    }

    // MARK: Stima

    @Test func theEstimateRequestSendsOnlyActionTypeAndEffort() throws {
        let data = try JSONEncoder().encode(AriaUsageEstimateRequest(effort: .high))
        let sent = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])

        #expect(sent == ["action_type": "chat.reply", "effort": "high"])
    }

    @Test func theEstimateReadsItsFiguresLeniently() throws {
        let estimate = try UsageFixture.decode(AriaUsageEstimate.self,
                                               #"{"effort_effective":"high","credits_each":"2.4","allowance_impact_each":7,"degraded":"x"}"#)

        #expect(estimate.effortEffective == "high")
        #expect(estimate.creditsEach == d("2.4"))
        #expect(estimate.allowanceImpactEach == 7)
        #expect(!estimate.degraded)
    }
}

@Suite("Spend cap 402")
struct UsageSpendCapTests {
    private func response(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://x.test/v1/responses")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    private func check(_ status: Int, _ body: String) -> AriaError? {
        do {
            try AriaHTTP.check(response(status), Data(body.utf8))
            return nil
        } catch {
            return error as? AriaError
        }
    }

    @Test func aSpendCapRefusalIsItsOwnError() throws {
        let error = try #require(check(402, #"{"error":{"type":"spend_cap_reached","message":"Limit reached","code":402,"request_id":"r1"}}"#))

        guard case .spendCapReached(let message) = error else { Issue.record("atteso .spendCapReached, trovato \(error)"); return }
        #expect(message == "Limit reached")
        #expect(error.errorDescription == "Your company's spending limit is reached. An owner or admin can raise it.")
    }

    @Test func anotherPaymentErrorStaysAGenericHTTPError() throws {
        let error = try #require(check(402, #"{"error":{"type":"payment_required","message":"Pay up","code":402}}"#))

        guard case .http(let status, let detail) = error else { Issue.record("atteso .http, trovato \(error)"); return }
        #expect(status == 402)
        #expect(detail == "Pay up")
    }

    @Test(arguments: ["", "<html>Payment required</html>", "not json", "{}", #"{"error":"spend_cap_reached"}"#])
    func aPaymentErrorWithoutTheTypedBodyStaysGeneric(body: String) throws {
        let error = try #require(check(402, body))

        guard case .http(let status, _) = error else { Issue.record("atteso .http, trovato \(error)"); return }
        #expect(status == 402)
    }

    @Test func theSameTypeOnAnotherStatusIsNotTheSpendCap() throws {
        let error = try #require(check(500, #"{"error":{"type":"spend_cap_reached","message":"x","code":500}}"#))

        guard case .http(let status, _) = error else { Issue.record("atteso .http, trovato \(error)"); return }
        #expect(status == 500)
    }
}

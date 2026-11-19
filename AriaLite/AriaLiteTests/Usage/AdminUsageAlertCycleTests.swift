//
//  AdminUsageAlertCycleTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'avviso della pagina Usage (contratto 3.3), parte seconda: il modo "day" (casi 4), nessun piano assegnato (5) e il
//  ciclo ordinario (6). Il titolare che vede i soldi, il titolare che non li vede, il membro, la frase tralasciata e le
//  azioni di ogni caso.
//

import Foundation
import Testing
@testable import AriaLite

private typealias Fx = UsageFixture

@Suite("Usage alert: day mode, no plan and cycle")
struct AdminUsageAlertCycleTests {
    private var dayPeriod: [String: Any] {
        ["mode": "day", "today_included": "175", "today_consumed": "140", "today_overage_credits": "0",
         "today_overage_amount": "0"]
    }

    private func day(_ state: String, period extra: [String: Any] = [:], member: Bool = false,
                     top: [String: Any?] = [:]) throws -> AriaUsageDashboard {
        var period = dayPeriod
        period.merge(extra) { _, new in new }
        var all: [String: Any?] = ["state": state]
        all.merge(top) { _, new in new }
        if member { return try Fx.memberDashboard(period: period, top: all) }
        return try Fx.adminDashboard(period: period, top: all)
    }

    // MARK: 4. Modo "day", avviso

    @Test func aDayNoticeForAnOwnerWhoSeesMoneySaysTheExtraPrice() throws {
        let alert = try #require(try Fx.adminAlert(day("notice"), allowance: Fx.adminAllowance(top: ["meters": NSNull()])))

        #expect(alert.tone == .warning)
        #expect(alert.title == "You've used 80% of today's credits")
        #expect(alert.body == "Past today's 175 included credits, extra credits are billed at €0.16 each until the day resets at 00:00 UTC.")
        #expect(alert.actions.map(\.label) == ["Set a spending limit", "Upgrade to Enterprise"])
    }

    @Test func aDayNoticeOffersNoLimitActionUntilTheAllowanceIsReadOrWhenOneIsInForce() throws {
        let unread = try #require(try Fx.adminAlert(day("notice")))
        let withLimit = try #require(try Fx.adminAlert(
            day("notice"), allowance: Fx.adminAllowance(spendCap: Fx.cap("ok"), top: ["meters": NSNull()])))

        #expect(unread.actions.isEmpty)
        #expect(withLimit.actions.map(\.label) == ["Upgrade to Enterprise"])
    }

    @Test func anOwnerWhoSeesMoneyWhoseExtraCreditsAreNotBilledReadsTheLimitSentence() throws {
        let board = try day("notice", period: ["extra_credits_billable": false])
        let withLimit = try #require(try Fx.adminAlert(board, allowance: Fx.adminAllowance(spendCap: Fx.cap("ok", amount: "0", billed: "0"), top: ["meters": NSNull()])))
        let unread = try #require(try Fx.adminAlert(board))

        #expect(withLimit.title == "You've used 80% of today's credits")
        #expect(withLimit.body == "Past today's 175 included credits, answers use a lighter model until the day resets at 00:00 UTC. With a limit of €0, nothing extra is billed.")
        // Senza il tetto letto, la frase del membro.
        #expect(unread.body == "Past today's 175 included credits, replies use a lighter model until 00:00 UTC. Owners have been notified.")
    }

    @Test func anOwnerWhoSeesNoMoneyReadsTheMembersWordsExceptWhenExtraCreditsAreNotBilled() throws {
        let billed = try day("notice", top: ["amounts_visible": false])
        let notBilled = try day("notice", period: ["extra_credits_billable": false], top: ["amounts_visible": false])

        let blind = try #require(try Fx.adminAlert(billed))
        #expect(blind.title == "Your company has used 80% of today's credits")
        #expect(blind.body == "Past today's 175 included credits, extra credits are used until 00:00 UTC. Owners have been notified.")
        // L'eccezione: un titolare i cui extra non si addebitano tiene il titolo del titolare.
        let kept = try #require(try Fx.adminAlert(notBilled))
        #expect(kept.title == "You've used 80% of today's credits")
        #expect(kept.body == "Past today's 175 included credits, replies use a lighter model until 00:00 UTC. Owners have been notified.")
    }

    @Test func aMemberHasNoDayNoticeWhereTheTodayMeterIsDrawn() throws {
        let board = try day("notice", member: true)
        let config = try Fx.memberAdminConfig()
        let withMeters = try Fx.adminAlert(board, config: config, allowance: Fx.adminAllowance())
        let withoutMeters = try #require(try Fx.adminAlert(board, config: config, allowance: Fx.adminAllowance(top: ["meters": NSNull()])))
        let unread = try #require(try Fx.adminAlert(board, config: config))

        #expect(withMeters == nil)
        #expect(withoutMeters.title == "Your company has used 80% of today's credits")
        #expect(withoutMeters.body == "Past today's 175 included credits, extra credits are used until 00:00 UTC. Owners have been notified.")
        #expect(unread.title == withoutMeters.title)
    }

    @Test func anOwnerKeepsTheDayNoticeEvenWhereTheMeterIsDrawn() throws {
        let alert = try Fx.adminAlert(day("notice"), allowance: Fx.adminAllowance())

        #expect(alert != nil)
    }

    @Test func aMemberWhoseExtraCreditsAreNotBilledReadsTheLighterModelSentence() throws {
        let board = try day("notice", period: ["extra_credits_billable": false], member: true)
        let alert = try #require(try Fx.adminAlert(board, config: Fx.memberAdminConfig()))

        #expect(alert.body == "Past today's 175 included credits, replies use a lighter model until 00:00 UTC. Owners have been notified.")
        #expect(alert.actions.isEmpty)
    }

    @Test func aDayNoticeLeavesTheBodyOutWhenTodaysIncludedCreditsAreMissing() throws {
        let board = try day("notice", period: ["today_included": NSNull()], member: true)
        let alert = try #require(try Fx.adminAlert(board, config: Fx.memberAdminConfig()))

        #expect(alert.body == nil)
    }

    // MARK: 4. Modo "day", extra e tetto

    @Test func aDayOverageForAnOwnerWhoSeesMoneyNamesTheAmountAndThePrice() throws {
        let board = try day("overage", period: ["today_overage_credits": "12.5", "today_overage_amount": "2"])
        let alert = try #require(try Fx.adminAlert(board, allowance: Fx.adminAllowance()))

        #expect(alert.title == "Today's credits are used up: €2.00 extra today")
        #expect(alert.body == "12.5 credits past today's 175 included, at €0.16 per credit. Answers continue as usual; the included credits start again at 00:00 UTC.")
        #expect(alert.actions.map(\.label) == ["Set a spending limit", "Upgrade to Enterprise"])
    }

    @Test func aDayOverageForEveryoneElseIsCreditsOnlyAndAMissingAmountFallsBackToIt() throws {
        let member = try day("overage", period: ["today_overage_credits": "12.5"], member: true)
        let noAmount = try day("overage", period: ["today_overage_credits": "12.5", "today_overage_amount": NSNull()])

        let alert = try #require(try Fx.adminAlert(member, config: Fx.memberAdminConfig()))
        #expect(alert.title == "Today's credits are used up")
        #expect(alert.body == "12.5 credits past today's 175 included. Answers continue as usual, using extra credits.")
        #expect(try Fx.adminAlert(noAmount)?.title == "Today's credits are used up")
    }

    @Test func aDayCappedStateForAnOwnerWhoSeesMoneyAndForEveryoneElse() throws {
        let config = try Fx.adminConfig(replacing: ["overage": Fx.degradeOverage])
        let owner = try #require(try Fx.adminAlert(
            day("capped"), config: config, allowance: Fx.adminAllowance(spendCap: Fx.cap("reached"))))
        let member = try #require(try Fx.adminAlert(
            day("capped", member: true), config: Fx.memberAdminConfig(replacing: ["overage": Fx.degradeOverage])))

        #expect(owner.tone == .critical)
        #expect(owner.title == "Spending limit reached: past today's credits, replies use a lighter model")
        #expect(owner.body == "Your limit of €500 is reached, so nothing more is billed this cycle. Each day, past its 175 included credits, AriA answers with a lighter model until the cycle resets on Dec 1. Raise the limit to go back to the standard model.")
        #expect(owner.actions.map(\.label) == ["Change limit", "Upgrade to Enterprise"])
        #expect(member.title == "Past today's credits, replies use a lighter model")
        #expect(member.body == "Your company reached its spending limit. An owner can raise it.")
        #expect(member.actions.isEmpty)
    }

    @Test func aDayAlertForAHealthyDayIsNone() throws {
        #expect(try Fx.adminAlert(day("ok")) == nil)
        #expect(try Fx.adminAlert(day("pacing")) == nil)
    }

    // MARK: 5. Nessun piano

    private func noPlan(_ state: String, period: [String: Any] = [:], top: [String: Any?] = [:]) throws -> AriaUsageDashboard {
        var all: [String: Any?] = ["state": state, "tier_source": "unassigned_fallback", "amounts_visible": false]
        all.merge(top) { _, new in new }
        return try Fx.adminDashboard(period: period, top: all)
    }

    @Test func noPlanWithExtraCreditsIsInfoForAnOwnerAndWarningForAMember() throws {
        let board = try noPlan("overage", period: ["overage_credits": "250.5"])
        let owner = try #require(try Fx.adminAlert(board))
        let member = try #require(try Fx.adminAlert(board, config: Fx.memberAdminConfig()))

        #expect(owner.tone == .info)
        #expect(owner.title == "No plan is assigned yet; your company runs on Basic.")
        #expect(owner.body == "250.5 credits past the 5,250 included this cycle. They are not billed while no plan is assigned, and answers continue as usual.")
        #expect(member.tone == .warning)
        #expect(member.title == "Your company is using extra credits")
        #expect(member.body == "250.5 credits past the 5,250 included this cycle. Replies work as usual.")
    }

    @Test func noPlanNoticeOwnerAndMember() throws {
        let board = try noPlan("notice")
        let owner = try #require(try Fx.adminAlert(board))
        let member = try #require(try Fx.adminAlert(board, config: Fx.memberAdminConfig()))

        #expect(owner.tone == .warning)
        #expect(owner.title == "You've used 73% of this cycle's credits")
        #expect(owner.body == "No plan is assigned yet; your company runs on Basic. Extra credits are not billed, and work continues as usual.")
        #expect(member.title == "Your company has used 73% of this cycle's credits")
        #expect(member.body == "At this pace it will use about 1,137.3 extra credits by Nov 30. Owners have been notified.")
    }

    @Test func noPlanOtherwiseIsAnInfoLineForTheOwnerOnly() throws {
        let board = try noPlan("ok")
        let owner = try #require(try Fx.adminAlert(board))

        #expect(owner.tone == .info)
        #expect(owner.title == "No plan is assigned yet; your company runs on Basic.")
        #expect(owner.body == nil)
        #expect(try Fx.adminAlert(board, config: Fx.memberAdminConfig()) == nil)
    }

    @Test func noPlanOffersNoActionsAndKeepsAMembersNoticeWithoutAProjectionBodyless() throws {
        let board = try noPlan("notice", top: ["projection": NSNull()])
        let owner = try #require(try Fx.adminAlert(board, allowance: Fx.adminAllowance()))
        let member = try #require(try Fx.adminAlert(board, config: Fx.memberAdminConfig()))

        #expect(owner.actions.isEmpty)
        #expect(member.body == nil)
    }

    @Test func noPlanInDayModeKeepsTheOwnersNoPlanSentence() throws {
        // Senza un piano il server non addebita nulla: `extra_credits_billable` è falso, e l'avviso resta del titolare.
        let board = try day("notice", period: ["extra_credits_billable": false],
                            top: ["tier_source": "unassigned_fallback", "amounts_visible": false])
        let alert = try #require(try Fx.adminAlert(board))

        #expect(alert.title == "You've used 80% of today's credits")
        #expect(alert.body == "No plan is assigned yet; your company runs on Basic. Extra credits are not billed, and work continues as usual.")
    }

    // MARK: 6. Ciclo

    @Test func aCycleNoticeForAnOwnerWhoSeesMoneyProjectsTheExtraCredits() throws {
        let alert = try #require(try Fx.adminAlert(allowance: Fx.adminAllowance()))

        #expect(alert.tone == .warning)
        #expect(alert.title == "You've used 73% of this cycle's credits")
        #expect(alert.body == "At this pace your company will use about 1,137.3 extra credits by Nov 30, billed at €0.16 each (≈ €181.97).")
        #expect(alert.actions.map(\.label) == ["Set a spending limit", "Upgrade to Enterprise"])
    }

    @Test func aCycleNoticeOnAPoolNamesThePoolAndOneWithALimitHasNoLimitAction() throws {
        let pool = try Fx.adminDashboard(top: ["mode": "pool"])
        let alert = try #require(try Fx.adminAlert(pool, allowance: Fx.adminAllowance(spendCap: Fx.cap("ok"))))

        #expect(alert.title == "You've used 73% of this month's credit pool")
        #expect(alert.actions.map(\.label) == ["Upgrade to Enterprise"])
    }

    @Test func aCycleNoticeBeforeTheAllowanceIsReadHasNoActions() throws {
        let alert = try #require(try Fx.adminAlert())

        #expect(alert.actions.isEmpty)
    }

    @Test func aCycleNoticeWhoseExtraCreditsAreNotBilledSaysTheLighterModel() throws {
        let board = try Fx.adminDashboard(period: ["extra_credits_billable": false])
        let alert = try #require(try Fx.adminAlert(board))

        #expect(alert.body == "You can keep working. Beyond 100%, answers use a lighter model.")
    }

    @Test func aCycleNoticeDropsTheBodyWithoutAProjectionPastTheIncludedOrWithoutAPrice() throws {
        let within = try Fx.adminDashboard(top: ["projection": Fx.withinProjection])
        let noAmount = try Fx.adminDashboard(top: ["projection": ["until": "2026-11-30", "days_left": 12, "window_days": 7,
                                                                   "daily_average": "212.9", "projected": "6387.3",
                                                                   "overage_credits": "1137.3", "overage_amount": NSNull()]])
        let noPrice = try Fx.adminDashboard(period: ["price_per_credit": NSNull()])

        #expect(try #require(try Fx.adminAlert(within)).body == nil)
        #expect(try #require(try Fx.adminAlert(noAmount)).body == nil)
        #expect(try #require(try Fx.adminAlert(noPrice)).body == nil)
    }

    @Test func aCycleNoticeForAMemberAndForAnOwnerWhoSeesNoMoneyHasTheCompanyWords() throws {
        let member = try #require(try Fx.adminAlert(Fx.memberDashboard(), config: Fx.memberAdminConfig()))
        let blind = try #require(try Fx.adminAlert(Fx.adminDashboard(top: ["amounts_visible": false])))

        #expect(member.title == "Your company has used 73% of this cycle's credits")
        #expect(member.body == "At this pace it will use about 1,137.3 extra credits by Nov 30. Owners have been notified.")
        #expect(member.actions.isEmpty)
        #expect(blind.title == member.title)
        #expect(blind.body == member.body)
    }

    private func overage(_ top: [String: Any?] = [:]) throws -> AriaUsageDashboard {
        var all: [String: Any?] = ["state": "overage"]
        all.merge(top) { _, new in new }
        return try Fx.adminDashboard(period: ["overage_credits": "250.5", "overage_amount": "40.08"], top: all)
    }

    @Test func aCycleOverageNamesTheAmountAndWhetherALimitIsSet() throws {
        let none = try #require(try Fx.adminAlert(overage(), allowance: Fx.adminAllowance()))
        let withLimit = try #require(try Fx.adminAlert(overage(), allowance: Fx.adminAllowance(spendCap: Fx.cap("ok"))))
        let unread = try #require(try Fx.adminAlert(overage()))

        #expect(none.title == "You're using extra credits: €40.08 so far")
        #expect(none.body == "250.5 credits past the 5,250 included, at €0.16 per credit. No spending limit is set, so extra credits are billed until the cycle resets on Dec 1.")
        #expect(none.actions.map(\.label) == ["Set a spending limit", "Upgrade to Enterprise"])
        #expect(withLimit.body == "250.5 credits past the 5,250 included, at €0.16 per credit. Your spending limit is €500 per cycle.")
        #expect(withLimit.actions.map(\.label) == ["Change limit", "Upgrade to Enterprise"])
        // Se c'è un tetto lo dice solo il saldo: finché non è letto, il titolo da solo e nessuna azione.
        #expect(unread.body == nil)
        #expect(unread.actions.isEmpty)
    }

    @Test func aCycleOverageForEveryoneElseIsCreditsOnly() throws {
        let member = try #require(try Fx.adminAlert(overage(["amounts_visible": false]), config: Fx.memberAdminConfig()))

        #expect(member.title == "Your company is using extra credits")
        #expect(member.body == "250.5 credits past the 5,250 included this cycle. Replies work as usual.")
    }

    @Test func aCycleCappedStateForAnOwnerAndAMember() throws {
        let config = try Fx.adminConfig(replacing: ["overage": Fx.degradeOverage])
        let board = try Fx.adminDashboard(top: ["state": "capped"])
        let owner = try #require(try Fx.adminAlert(board, config: config, allowance: Fx.adminAllowance(spendCap: Fx.cap("reached"))))
        let unread = try #require(try Fx.adminAlert(board, config: config))
        let member = try #require(try Fx.adminAlert(
            Fx.memberDashboard(top: ["state": "capped"]), config: Fx.memberAdminConfig(replacing: ["overage": Fx.degradeOverage])))

        #expect(owner.tone == .critical)
        #expect(owner.title == "Spending limit reached: replies use a lighter model")
        #expect(owner.body == "Your limit of €500 is reached, so nothing more is billed this cycle. Until the cycle resets on Dec 1, AriA answers with a lighter model. Raise the limit to go back to the standard model.")
        #expect(owner.actions.map(\.label) == ["Change limit", "Upgrade to Enterprise"])
        #expect(unread.body == nil)
        #expect(member.title == "Replies use a lighter model until Dec 1")
        #expect(member.body == "Your company reached its spending limit. An owner can raise it.")
        #expect(member.actions.isEmpty)
    }

    @Test func aHealthyCycleHasNoAlert() throws {
        #expect(try Fx.adminAlert(Fx.adminDashboard(top: ["state": "ok"])) == nil)
        #expect(try Fx.adminAlert(Fx.adminDashboard(top: ["state": "pacing"])) == nil)
        // Uno stato che l'app non conosce vale "ok".
        #expect(try Fx.adminAlert(Fx.adminDashboard(top: ["state": "mystery"])) == nil)
    }

    @Test func italianElidesTheArticleInATitle() throws {
        let board = try Fx.adminDashboard(period: ["pct": "0.82"])
        let facts = try Fx.adminFacts(dashboard: board)
        let config = try Fx.adminConfig()
        let italian = try #require(AdminUsageFacts(dashboard: board, config: config, allowance: nil, locale: Fx.italian))

        // L'elisione si applica al testo scritto: qui il catalogo è in inglese, quindi si verifica la regola e non la lingua.
        #expect(facts.pct == 82)
        #expect(italian.elide("Hai usato il 82% dei crediti di questo ciclo") == "Hai usato l'82% dei crediti di questo ciclo")
        #expect(facts.elide("Hai usato il 82% dei crediti di questo ciclo") == "Hai usato il 82% dei crediti di questo ciclo")
    }
}

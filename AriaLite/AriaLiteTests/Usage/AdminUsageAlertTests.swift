//
//  AdminUsageAlertTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'avviso che apre la pagina Usage (contratto 3.3), caso per caso nell'ordine della tabella: ciclo chiuso, prova,
//  tetto (raggiunto su un piano che si ferma, vicino), poi le azioni. Titolare con e senza soldi, membro, frasi tralasciate
//  quando una cifra non c'è. I casi del modo "day", di nessun piano e del ciclo sono in AdminUsageAlertCycleTests.
//

import Foundation
import Testing
@testable import AriaLite

private typealias Fx = UsageFixture

@Suite("Usage alert: closed, trial and spending limit")
struct AdminUsageAlertTests {
    // MARK: 1. Ciclo chiuso

    private func closedBoard(top: [String: Any?] = [:]) throws -> AriaUsageDashboard {
        var all: [String: Any?] = ["state": "ok", "today": NSNull(), "week": NSNull(), "projection": NSNull()]
        all.merge(top) { _, new in new }
        return try Fx.adminDashboard(period: ["closed": true, "start": "2026-10-01", "end": "2026-10-31"], top: all)
    }

    @Test func aClosedCycleIsInfoWithBackForEveryone() throws {
        let owner = try #require(try Fx.adminAlert(closedBoard()))
        let member = try #require(try Fx.adminAlert(closedBoard(), config: Fx.memberAdminConfig()))

        #expect(owner.tone == .info)
        #expect(owner.title == "You're viewing October 2026, a closed cycle")
        #expect(owner.body == "These figures are final. Today, the projection and the billing controls apply only to the current cycle.")
        #expect(member.body == "These figures are final. Today and the projection apply only to the current cycle.")
        #expect(owner.actions == [AdminUsageAlertAction(kind: .back, label: "Back to the current cycle")])
        #expect(member.actions == owner.actions)
    }

    @Test func aClosedCycleComesBeforeEveryOtherCase() throws {
        // Prova, tetto raggiunto e modo "day" insieme: vince il ciclo chiuso.
        let board = try closedBoard(top: ["state": "capped", "trial": ["starts_on": "2026-10-01", "ends_on": "2026-10-20", "days_left": 0]])
        let alert = try #require(try Fx.adminAlert(board))

        #expect(alert.title == "You're viewing October 2026, a closed cycle")
    }

    // MARK: 2. Prova

    @Test func theTrialWhenCappedWarnsAndOffersToChooseAPlanToAnOwner() throws {
        let board = try Fx.adminDashboard(top: Fx.trialTop.merging(["state": "capped"]) { _, new in new })
        let alert = try #require(try Fx.adminAlert(board))

        #expect(alert.tone == .warning)
        #expect(alert.title == "Trial credits used: replies use a lighter model")
        #expect(alert.body == "Your free trial's 5,250 credits are used. Until the trial ends on Nov 24, AriA answers with a lighter model and nothing is billed. To keep the standard model, choose a plan.")
        let action = try #require(alert.actions.first)
        #expect(alert.actions.count == 1)
        #expect(action.label == "Choose a plan")
        guard case .plan(let url) = action.kind else { Issue.record("expected a mail action"); return }
        #expect(url.absoluteString == "mailto:sales@example.test?subject=Choose%20a%20plan")
    }

    @Test func theTrialWhenCappedForAMemberSaysAnOwnerCanChooseAPlan() throws {
        let board = try Fx.memberDashboard(top: Fx.trialTop.merging(["state": "capped"]) { _, new in new })
        let alert = try #require(try Fx.adminAlert(board, config: Fx.memberAdminConfig()))

        #expect(alert.title == "Replies use a lighter model until Nov 24")
        #expect(alert.body == "Your company has used the free trial's included credits. An owner can choose a plan.")
        #expect(alert.actions.isEmpty)
    }

    @Test func theTrialNoticeNeedsAProjectionPastTheIncludedCredits() throws {
        let noticed = try Fx.adminDashboard(top: Fx.trialTop.merging(["state": "notice"]) { _, new in new })
        let within = try Fx.adminDashboard(top: Fx.trialTop.merging(["state": "notice", "projection": Fx.withinProjection]) { _, new in new })

        let warning = try #require(try Fx.adminAlert(noticed))
        #expect(warning.tone == .warning)
        #expect(warning.title == "73% of the free trial's credits used")
        #expect(warning.body == "At this pace the included credits run out before the trial ends on Nov 24. After that, AriA answers with a lighter model; nothing is billed.")
        // Sotto gli inclusi resta la riga della prova.
        let info = try #require(try Fx.adminAlert(within))
        #expect(info.tone == .info)
        #expect(info.title == "Free trial · 6 days left")
    }

    @Test func theTrialLineSaysTheDailyCreditsAndAZeroLimit() throws {
        let alert = try #require(try Fx.adminAlert(Fx.adminDashboard(top: Fx.trialTop.merging(["state": "ok"]) { _, new in new })))

        #expect(alert.tone == .info)
        #expect(alert.title == "Free trial · 6 days left")
        #expect(alert.body == "Your trial includes 25 credits a day for your one user. The spending limit is €0, so extra credits are never billed: past the included credits, AriA answers with a lighter model.")
    }

    @Test func theTrialTitleHasASingularAndDropsAMissingDayCount() throws {
        var oneDay = Fx.trialTop
        oneDay["trial"] = ["starts_on": "2026-11-10", "ends_on": "2026-11-19", "days_left": 1]
        var noDays = Fx.trialTop
        noDays["trial"] = ["starts_on": "2026-11-10", "ends_on": "2026-11-19"]

        #expect(try Fx.adminAlert(Fx.adminDashboard(top: oneDay))?.title == "Free trial · 1 day left")
        #expect(try Fx.adminAlert(Fx.adminDashboard(top: noDays))?.title == "Free trial")
    }

    @Test func theTrialLineLeavesOutTheDailyCreditsWhenNoSourceStatesThem() throws {
        var top = Fx.trialTop
        top["trial"] = ["starts_on": "2026-11-10", "ends_on": "2026-11-24", "days_left": 6]
        let board = try Fx.adminDashboard(period: ["included": NSNull()], top: top)
        let alert = try #require(try Fx.adminAlert(board, config: Fx.adminConfig(replacing: ["plan": NSNull()])))

        #expect(alert.title == "Free trial · 6 days left")
        #expect(alert.body == nil)
    }

    @Test func theTrialComesBeforeTheSpendingLimit() throws {
        let board = try Fx.adminDashboard(top: Fx.trialTop.merging(["state": "capped"]) { _, new in new })
        let alert = try #require(try Fx.adminAlert(board, allowance: Fx.adminAllowance(spendCap: Fx.cap("reached"))))

        #expect(alert.title == "Trial credits used: replies use a lighter model")
    }

    @Test func noPlanChooseActionWithoutASalesAddress() throws {
        let board = try Fx.adminDashboard(top: Fx.trialTop.merging(["state": "ok"]) { _, new in new })
        var ui: [String: Any] = ["sales_contact_email": ""]
        ui["projection_window_days"] = 7
        let alert = try #require(try Fx.adminAlert(board, config: Fx.adminConfig(replacing: ["ui": ui])))

        #expect(alert.actions.isEmpty)
    }

    // MARK: 3. Tetto raggiunto su un piano che si ferma

    private func capped() throws -> AriaUsageDashboard { try Fx.adminDashboard(top: ["state": "capped"]) }

    @Test func aReachedLimitOnAStoppingDailyPlanSaysItToAnOwnerWhoSeesMoney() throws {
        let alert = try #require(try Fx.adminAlert(capped(), allowance: Fx.adminAllowance(spendCap: Fx.cap("reached", billed: "500"))))

        #expect(alert.tone == .critical)
        #expect(alert.title == "Monthly spending limit reached")
        #expect(alert.body == "Your limit of €500 is reached, so nothing more is billed this cycle. Until Dec 1, usage past each day's included credits stops. Usage within the daily credits still works.")
        #expect(alert.actions.map(\.label) == ["Raise the limit", "Upgrade to Enterprise"])
        #expect(alert.actions.first?.kind == .limit)
    }

    @Test func aReachedLimitOnAPoolUsesTheCycleWords() throws {
        let allowance = try Fx.adminAllowance(spendCap: Fx.cap("reached"), top: ["mode": "pool"])
        let alert = try #require(try Fx.adminAlert(capped(), allowance: allowance))

        #expect(alert.body == "Your limit of €500 is reached, so nothing more is billed this cycle. Until Dec 1, usage past the included credits stops. Usage within the included credits still works.")
    }

    @Test func theLimitIsReachedWhenTheAllowanceSaysSoEvenIfTheStateIsNot() throws {
        let alert = try #require(try Fx.adminAlert(allowance: Fx.adminAllowance(spendCap: Fx.cap("reached"))))

        #expect(alert.title == "Monthly spending limit reached")
    }

    @Test func whileTheAllowanceIsUnreadTheReachedAlertIsTheTitleAlone() throws {
        let alert = try #require(try Fx.adminAlert(capped()))

        #expect(alert.title == "Monthly spending limit reached")
        #expect(alert.body == nil)
        // "Raise the limit" ci va già; l'upgrade aspetta il saldo.
        #expect(alert.actions.map(\.label) == ["Raise the limit"])
    }

    @Test func anOwnerWhoSeesNoMoneyReadsTheEuroFreeStopSentence() throws {
        let board = try Fx.adminDashboard(top: ["state": "capped", "amounts_visible": false])
        let allowance = try Fx.adminAllowance(spendCap: Fx.cap("reached"), top: ["amounts_visible": false])
        let alert = try #require(try Fx.adminAlert(board, allowance: allowance))

        #expect(alert.title == "Monthly spending limit reached")
        #expect(alert.body == "Until Dec 1, usage past each day's included credits stops. Usage within the daily credits still works. Raise the limit to resume right away.")
        #expect(alert.actions.map(\.label) == ["Raise the limit", "Upgrade to Enterprise"])
    }

    @Test func aMemberReadsThatAnOwnerCanRaiseTheLimitAndGetsNoActions() throws {
        let board = try Fx.memberDashboard(top: ["state": "capped"])
        let alert = try #require(try Fx.adminAlert(board, config: Fx.memberAdminConfig()))

        #expect(alert.tone == .critical)
        #expect(alert.title == "Monthly spending limit reached")
        #expect(alert.body == "Until Dec 1, usage past the included credits stops. An owner can raise the limit.")
        #expect(alert.actions.isEmpty)
    }

    @Test func aPlanThatDegradesNeverGetsTheStopAlert() throws {
        let config = try Fx.adminConfig(replacing: ["overage": Fx.degradeOverage])
        let alert = try #require(try Fx.adminAlert(capped(), config: config, allowance: Fx.adminAllowance(spendCap: Fx.cap("reached"))))

        // Cade al caso del ciclo: "Spending limit reached: replies use a lighter model".
        #expect(alert.title == "Spending limit reached: replies use a lighter model")
    }

    @Test func noPlanAssignedNeverGetsTheLimitAlert() throws {
        let board = try Fx.adminDashboard(top: ["state": "capped", "tier_source": "unassigned_fallback"])
        let alert = try #require(try Fx.adminAlert(board, allowance: Fx.adminAllowance(spendCap: Fx.cap("reached"))))

        #expect(alert.title == "No plan is assigned yet; your company runs on Basic.")
        #expect(alert.actions.isEmpty)
    }

    // MARK: 3. Tetto vicino

    private func warnedBoard(_ top: [String: Any?] = [:]) throws -> AriaUsageDashboard {
        var all: [String: Any?] = ["state": "ok", "spend_cap": Fx.dashboardCap("warned")]
        all.merge(top) { _, new in new }
        return try Fx.adminDashboard(top: all)
    }

    @Test func aLimitCloseWarnsAnOwnerWhoSeesMoneyWithEurosAndTheServersPercent() throws {
        let config = try Fx.adminConfig(replacing: ["overage": Fx.degradeOverage])
        let alert = try #require(try Fx.adminAlert(warnedBoard(), config: config, allowance: Fx.adminAllowance(spendCap: Fx.cap("warned"))))

        #expect(alert.tone == .warning)
        #expect(alert.title == "You've used 82% of your spending limit: €410.00 of €500")
        #expect(alert.body == "At €500, AriA switches to a lighter model and nothing more is billed.")
        #expect(alert.actions.map(\.label) == ["Change limit", "Upgrade to Enterprise"])
    }

    @Test func aLimitCloseOnAStoppingPlanSaysWhatStops() throws {
        let day = try #require(try Fx.adminAlert(warnedBoard(), allowance: Fx.adminAllowance(spendCap: Fx.cap("warned"))))
        let pool = try #require(try Fx.adminAlert(
            warnedBoard(), allowance: Fx.adminAllowance(spendCap: Fx.cap("warned"), top: ["mode": "pool"])))
        // Il saldo manca: nessun avviso del tetto, e il ciclo è "ok".
        let unread = try Fx.adminAlert(warnedBoard(), allowance: nil)

        #expect(unread == nil)
        #expect(day.body == "At €500, usage past each day's included credits stops until the cycle resets on Dec 1.")
        #expect(pool.body == "At €500, usage past the included credits stops until the cycle resets on Dec 1.")
    }

    @Test func aLimitCloseCarriesEurosSoOnlyAnOwnerWhoSeesMoneyGetsIt() throws {
        let allowance = try Fx.adminAllowance(spendCap: Fx.cap("warned"))
        let member = try Fx.adminAlert(Fx.warnedMemberBoard(), config: Fx.memberAdminConfig(), allowance: allowance)
        let blind = try Fx.adminAlert(warnedBoard(["amounts_visible": false]), allowance: allowance)

        // Il ciclo è "ok": nessun avviso né per il membro né per il titolare senza soldi.
        #expect(member == nil)
        #expect(blind == nil)
    }

    @Test func aLimitCloseNeedsTheServersPercentAndNeverComputesIt() throws {
        let board = try warnedBoard(["spend_cap": Fx.dashboardCap("warned", percent: nil)])
        let alert = try Fx.adminAlert(board, allowance: Fx.adminAllowance(spendCap: Fx.cap("warned")))

        #expect(alert == nil)
    }

    @Test func aLimitCloseGivesWayToACappedState() throws {
        let board = try warnedBoard(["state": "capped"])
        let config = try Fx.adminConfig(replacing: ["overage": Fx.degradeOverage])
        let alert = try #require(try Fx.adminAlert(board, config: config, allowance: Fx.adminAllowance(spendCap: Fx.cap("warned"))))

        #expect(alert.title == "Spending limit reached: replies use a lighter model")
    }

    // MARK: Azioni

    @Test func upgradeOpensAMailToSalesNamingThePlan() throws {
        let alert = try #require(try Fx.adminAlert(capped(), allowance: Fx.adminAllowance(spendCap: Fx.cap("reached"))))
        let upgrade = try #require(alert.actions.last)

        guard case .plan(let url) = upgrade.kind else { Issue.record("expected a mail action"); return }
        #expect(upgrade.label == "Upgrade to Enterprise")
        #expect(url.absoluteString == "mailto:sales@example.test?subject=AriA%20plan%20request%3A%20Enterprise")
    }

    @Test func thePlanActionIsHiddenWhenTheSalesAddressIsEmpty() throws {
        let config = try Fx.adminConfig(replacing: ["ui": ["sales_contact_email": "", "projection_window_days": 7]])
        let alert = try #require(try Fx.adminAlert(capped(), config: config, allowance: Fx.adminAllowance(spendCap: Fx.cap("reached"))))

        #expect(alert.actions.map(\.label) == ["Raise the limit"])
    }

    @Test func upgradeIsHiddenWhenNoHigherPlanIncludesMoreCredits() throws {
        // Enterprise è il piano più alto: niente di più grande da proporre.
        let board = try Fx.adminDashboard(top: ["state": "capped", "tier": "enterprise"])
        let config = try Fx.adminConfig(replacing: ["plan": ["tier": "enterprise"]])
        let alert = try #require(try Fx.adminAlert(board, config: config, allowance: Fx.adminAllowance(spendCap: Fx.cap("reached"))))

        #expect(alert.actions.map(\.label) == ["Raise the limit"])
    }
}

extension UsageFixture {
    /// Un cruscotto di membro con il tetto vicino.
    static func warnedMemberBoard() throws -> AriaUsageDashboard {
        try memberDashboard(top: ["state": "ok", "spend_cap": dashboardCap("warned")])
    }
}

//
//  AdminUsageFactsTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I fatti che ogni riquadro della pagina Usage legge (contratto 3.1 e sezione 6): titolare, "vede i soldi", modo day,
//  pool, prova, nessun piano, conteggio a dimensione, "daily" e le sue ripiegature, oggi dal server. Più la nuova
//  lettura di `period.closed` e il titolo con i giorni che restano.
//

import Foundation
import Testing
@testable import AriaLite

@Suite("Usage facts")
struct AdminUsageFactsTests {
    private func d(_ text: String) -> Decimal { UsageFixture.d(text) }

    @Test func theContractExampleForAnOwnerWhoSeesMoney() throws {
        let f = try UsageFixture.adminFacts()

        #expect(f.owner)
        #expect(f.seesMoney)
        #expect(f.textOwner)
        #expect(!f.closed)
        #expect(!f.dayMode)
        #expect(!f.pool)
        #expect(!f.noPlan)
        #expect(f.trial == nil)
        #expect(f.currency == "EUR")
        #expect(f.included == 5250)
        #expect(f.pct == 73)
        #expect(f.noticeShare == d("0.7"))
        // 3 832.5 contro 3 015.0 con base "max": si conta a dimensione.
        #expect(f.bySize)
        #expect(f.perUser)
        #expect(f.daily == 175)
        #expect(f.todayDaily == 175)
        #expect(f.priceText == "€0.16")
        #expect(f.reset == "Dec 1")
        #expect(f.monthName == "November 2026")
        #expect(f.stop)
        #expect(f.email == "sales@example.test")
    }

    @Test func periodClosedIsRead() throws {
        let open = try UsageFixture.allowance().period
        let closed = try UsageFixture.allowance(period: ["closed": true]).period
        let missing = try UsageFixture.decode(AriaAllowance.Period.self, #"{"mode": "cycle"}"#)

        #expect(open?.closed == false)
        #expect(closed?.closed == true)
        #expect(missing.closed == false)
    }

    @Test func anOwnerWhoDoesNotSeeMoneyReadsTheMembersWords() throws {
        let noDashboardMoney = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(top: ["amounts_visible": false]))
        let noConfigMoney = try UsageFixture.adminFacts(config: UsageFixture.adminConfig(replacing: ["amounts_visible": false]))

        #expect(noDashboardMoney.owner)
        #expect(!noDashboardMoney.seesMoney)
        #expect(!noDashboardMoney.textOwner)
        #expect(noDashboardMoney.priceText == nil)
        #expect(!noConfigMoney.seesMoney)
    }

    @Test func aMemberIsNotAnOwnerEvenWithAdminAccess() throws {
        let f = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(top: ["amounts_visible": false]),
                                            config: UsageFixture.memberAdminConfig())

        #expect(!f.owner)
        #expect(!f.textOwner)
        #expect(!f.showLimitCard)
    }

    @Test func noPlanAssignedNeverSeesMoney() throws {
        let f = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(top: ["tier_source": "unassigned_fallback"]))

        #expect(f.noPlan)
        #expect(!f.seesMoney)
        #expect(!f.showLimitCard)
        #expect(f.upgradeTier == nil)
    }

    @Test func theTrialAppliesToTheCurrentCycleOnly() throws {
        let trial: [String: Any] = ["starts_on": "2026-11-10", "ends_on": "2026-11-24", "days_left": 6]
        let current = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(top: ["trial": trial]))
        let closed = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(period: ["closed": true], top: ["trial": trial]))

        #expect(current.trial?.daysLeft == 6)
        #expect(!current.perUser)
        #expect(current.trialEnd == "Nov 24")
        #expect(closed.trial == nil)
    }

    @Test func dayModeAndAPool() throws {
        let day = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(
            period: ["mode": "day", "today_included": "175", "today_consumed": "40"]))
        let pool = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(top: ["mode": "pool"]))

        #expect(day.dayMode)
        #expect(day.todayDaily == 175)
        #expect(pool.pool)
        #expect(!pool.metersDrawn)
    }

    @Test func countedBySizeNeedsTheMaxBasisAndMoreThanTheCharge() throws {
        let credits = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(period: ["basis": "credits"]))
        let same = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(period: ["token_equivalent": "3015.0"]))

        #expect(!credits.bySize)
        #expect(!same.bySize)
    }

    @Test func dailyFollowsTheFallbackChain() throws {
        let noUsers = ["per_user_credits": NSNull(), "billed_users": NSNull()] as [String: Any?]
        let window = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(top: noUsers),
                                                 allowance: UsageFixture.adminAllowance())
        let plan = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(top: noUsers))
        let included = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(top: noUsers),
                                                   config: UsageFixture.adminConfig(replacing: ["plan": NSNull()]))
        let nothing = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(period: ["included": NSNull()], top: noUsers),
                                                  config: UsageFixture.adminConfig(replacing: ["plan": NSNull()]))

        // Il saldo dice 40 (finestra), poi il piano 25, poi gli inclusi diviso i giorni (5250 ÷ 30 = 175).
        #expect(window.daily == 40)
        #expect(plan.daily == 25)
        #expect(included.daily == 175)
        #expect(nothing.daily == nil)
    }

    @Test func perUserWinsOverEveryFallback() throws {
        let f = try UsageFixture.adminFacts(allowance: UsageFixture.adminAllowance())

        #expect(f.daily == 175)
    }

    @Test func todayIsTheLastSeriesDayNeverTheDeviceDate() throws {
        let f = try UsageFixture.adminFacts()
        let empty = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(top: ["series": [Any]()]))

        #expect(f.todayDay == "2026-11-18")
        #expect(empty.todayDay == nil)
    }

    @Test func theLowestNoticeThresholdUnderOneHundredPercentIsTheTick() throws {
        let f = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(top: ["notice_thresholds": ["1.00", "0.85", "0.6"]]))
        let none = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(top: ["notice_thresholds": ["1.00"]]))
        // Sul dashboard senza soglie vale quella del saldo.
        let fromAllowance = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(top: ["notice_thresholds": [String]()]),
                                                        allowance: UsageFixture.adminAllowance())

        #expect(f.noticeShare == d("0.6"))
        #expect(none.noticeShare == nil)
        #expect(fromAllowance.noticeShare == d("0.7"))
    }

    @Test func metersAreDrawnOnlyOnTheCurrentCycleOfADailyPlanWhoseAllowanceCarriesThem() throws {
        let allowance = try UsageFixture.adminAllowance()
        let drawn = try UsageFixture.adminFacts(allowance: allowance)
        let unread = try UsageFixture.adminFacts()
        let closed = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(period: ["closed": true]), allowance: allowance)
        let noMeters = try UsageFixture.adminFacts(allowance: UsageFixture.adminAllowance(top: ["meters": NSNull()]))

        #expect(drawn.metersDrawn)
        #expect(!unread.metersDrawn)
        #expect(!closed.metersDrawn)
        #expect(!noMeters.metersDrawn)
    }

    @Test func stopWordsComeFromTheAllowanceMode() throws {
        let day = try UsageFixture.adminFacts(allowance: UsageFixture.adminAllowance())
        let pool = try UsageFixture.adminFacts(allowance: UsageFixture.adminAllowance(top: ["mode": "pool"]))
        let unread = try UsageFixture.adminFacts()

        #expect(day.stopPeriod == .day)
        #expect(pool.stopPeriod == .cycle)
        #expect(unread.stopPeriod == nil)
    }

    @Test func theLimitComesFromTheAllowanceAndItsShareFromTheDashboardOnly() throws {
        let cap: [String: Any] = ["state": "warned", "amount": "500", "billed": "410"]
        let f = try UsageFixture.adminFacts(allowance: UsageFixture.adminAllowance(spendCap: cap))
        let unread = try UsageFixture.adminFacts()

        #expect(f.capKnown)
        #expect(f.capAmount == 500)
        #expect(f.capBilled == 410)
        #expect(f.capState == .warned)
        // `dashboard.spend_cap.percent` è 0 nell'esempio: l'app non ricalcola 410 ÷ 500.
        #expect(f.capPct == 0)
        #expect(!unread.capKnown)
        #expect(unread.capAmount == nil)
    }

    @Test func upgradeTargetNamesTheFirstHigherPlanWithMoreCredits() throws {
        let f = try UsageFixture.adminFacts(allowance: UsageFixture.adminAllowance())
        let unread = try UsageFixture.adminFacts()
        let member = try UsageFixture.adminFacts(config: UsageFixture.memberAdminConfig(), allowance: UsageFixture.adminAllowance())

        #expect(f.upgradeTier == "enterprise")
        // La web non offre l'upgrade finché il saldo non è letto; e mai a un membro.
        #expect(unread.upgradeTier == nil)
        #expect(member.upgradeTier == nil)
    }

    @Test func extraCreditsNotBilledIsAZeroLimitOnAPaidPlanOnly() throws {
        let paid = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(period: ["extra_credits_billable": false]))
        let noPlan = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(
            period: ["extra_credits_billable": false], top: ["tier_source": "unassigned_fallback"]))

        #expect(paid.capZero)
        #expect(!noPlan.capZero)
    }

    @Test func anUnreadableDashboardHasNoFacts() throws {
        let off = try UsageFixture.adminDashboard(top: ["enabled": false])
        let noPeriod = try UsageFixture.adminDashboard(top: ["period": NSNull()])
        let config = try UsageFixture.adminConfig()

        #expect(AdminUsageFacts(dashboard: off, config: config, allowance: nil) == nil)
        #expect(AdminUsageFacts(dashboard: noPeriod, config: config, allowance: nil) == nil)
    }

    // MARK: Intestazione e selettore

    @Test func theHeadingNamesThePlanAndTheMonthAndTheFactsLine() throws {
        let f = try UsageFixture.adminFacts()
        let heading = AdminUsageHeadingBuilder.build(f)

        #expect(heading.title == "Professional · November 2026 cycle")
        #expect(heading.facts == ["Nov 1 – Nov 30", "Resets Dec 1, 00:00 UTC", "12 days left"])
    }

    @Test func theLastDayAndTheDayModeAndAClosedCycle() throws {
        let last = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(top: [
            "series": [["day": "2026-11-30", "credits": "1", "token_equivalent": "1", "consumed": "1", "in_period": true]]]))
        let oneLeft = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(top: [
            "series": [["day": "2026-11-29", "credits": "1", "token_equivalent": "1", "consumed": "1", "in_period": true]]]))
        let day = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(period: ["mode": "day"]))
        let closed = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(
            period: ["closed": true, "start": "2026-10-01", "end": "2026-10-31"]))

        #expect(AdminUsageHeadingBuilder.build(last).facts.last == "Last day")
        #expect(AdminUsageHeadingBuilder.build(oneLeft).facts.last == "1 day left")
        #expect(AdminUsageHeadingBuilder.build(day).facts[1] == "Daily credits reset at 00:00 UTC")
        #expect(AdminUsageHeadingBuilder.build(closed).facts == ["Oct 1 – Oct 31", "Closed (UTC)"])
        #expect(AdminUsageHeadingBuilder.build(closed).title == "Professional · October 2026 cycle")
    }

    @Test func withoutASeriesDayTheDaysLeftAreLeftOut() throws {
        let f = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(top: ["series": [Any]()]))

        #expect(AdminUsageHeadingBuilder.build(f).facts == ["Nov 1 – Nov 30", "Resets Dec 1, 00:00 UTC"])
    }

    @Test func theTrialReadsFreeDemoOnTheCurrentCycleOnly() throws {
        let trial: [String: Any] = ["starts_on": "2026-11-10", "ends_on": "2026-11-24", "days_left": 6]
        let current = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(top: ["trial": trial]))
        let closed = try UsageFixture.adminFacts(dashboard: UsageFixture.adminDashboard(period: ["closed": true], top: ["trial": trial]))

        #expect(AdminUsageHeadingBuilder.build(current).title == "Free Demo · November 2026 cycle")
        #expect(AdminUsageHeadingBuilder.build(closed).title == "Professional · November 2026 cycle")
    }

    @Test func thePickerListsTheCyclesOfTheCurrentAnswerAndMarksTheCurrentOne() throws {
        let board = try UsageFixture.adminDashboard()
        let current = AriaUsageDashboard.Cycle(start: "2026-11-01", end: "2026-11-30")
        let options = AdminUsageHeadingBuilder.options(cycles: board.cycles, current: current, locale: UsageFixture.english)

        #expect(options.map(\.title) == ["November 2026 · current cycle", "October 2026"])
        #expect(options.map(\.isCurrent) == [true, false])
        #expect(options.map(\.id) == ["2026-11-01", "2026-10-01"])
    }

    @Test func anEmptyCycleListOffersTheCurrentCycleAlone() {
        let current = AriaUsageDashboard.Cycle(start: "2026-11-01", end: "2026-11-30")
        let options = AdminUsageHeadingBuilder.options(cycles: [], current: current, locale: UsageFixture.english)

        #expect(options.map(\.title) == ["November 2026 · current cycle"])
        #expect(AdminUsageHeadingBuilder.options(cycles: [], current: nil).isEmpty)
    }
}

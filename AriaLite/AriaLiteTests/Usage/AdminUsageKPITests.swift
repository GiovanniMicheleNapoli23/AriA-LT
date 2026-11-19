//
//  AdminUsageKPITests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le tessere delle cifre (contratto 3.4): modo ciclo (Today, This cycle, Included, Projection, Extra credits), modo
//  "day", prova, pool, nessun piano, ciclo chiuso; la barra (fino a 1, "over", tacca dell'avviso) e la riga sotto gli
//  Extra credits riga per riga.
//

import Foundation
import Testing
@testable import AriaLite

private typealias Fx = UsageFixture

@Suite("Usage KPI tiles")
struct AdminUsageKPITests {
    private func tiles(_ board: AriaUsageDashboard? = nil, config: AriaUsageConfig? = nil,
                       allowance: AriaAllowance? = nil) throws -> [AdminUsageKPI] {
        AdminUsageKPIBuilder.build(try Fx.adminFacts(dashboard: board, config: config, allowance: allowance))
    }

    private func tile(_ id: AdminUsageKPI.ID, _ list: [AdminUsageKPI]) throws -> AdminUsageKPI {
        try #require(list.first { $0.id == id })
    }

    // MARK: Modo ciclo

    @Test func theCycleTilesOfTheContractExampleForAnOwner() throws {
        let list = try tiles()

        #expect(list.map(\.id) == [.today, .cycle, .included, .projection, .extra])
        let today = try tile(.today, list)
        #expect(today.label == "Today")
        #expect(today.value == "38.4")
        #expect(today.unit == "credits")
        #expect(today.sub == "25 per user a day × 7 users")

        let cycle = try tile(.cycle, list)
        #expect(cycle.label == "This cycle")
        #expect(cycle.value == "3,832.5")
        #expect(cycle.sub == "of 5,250 included · 73%")
        #expect(cycle.note == "Long conversations count by size")
        #expect(cycle.bar == AdminUsageKPI.Bar(fraction: 0.73, isOver: false, tick: 0.7, tickLabel: "Notice at 70%"))

        let included = try tile(.included, list)
        #expect(included.value == "5,250")
        #expect(included.sub == "175 a day × 30 days")

        let projection = try tile(.projection, list)
        #expect(projection.value == "6,387.3")
        #expect(projection.sub == "by Nov 30 · 1,137.3 extra credits")
        #expect(projection.sub2 == "≈ €181.97 at this pace")

        let extra = try tile(.extra, list)
        #expect(extra.value == "0")
        #expect(extra.sub == "€0.16 per extra credit")
        #expect(!extra.isExtra)
    }

    @Test func todayIsLeftOutWhereTheTodayMeterIsDrawn() throws {
        let list = try tiles(allowance: Fx.adminAllowance())

        #expect(list.map(\.id) == [.cycle, .included, .projection, .extra])
    }

    @Test func aMemberReadsNoEurosAndNoPerUserLineChange() throws {
        let board = try Fx.memberDashboard()
        let list = try tiles(board, config: Fx.memberAdminConfig())

        #expect(try tile(.projection, list).sub2 == nil)
        #expect(try tile(.extra, list).sub == "None so far this cycle")
        #expect(try tile(.projection, list).sub == "by Nov 30 · 1,137.3 extra credits")
    }

    @Test func theBarStopsAtOneTurnsOverAtTheIncludedCreditsAndWaitsForTheFirstCreditToShowTheTick() throws {
        let over = try tiles(Fx.adminDashboard(period: ["consumed": "5250", "pct": "1.2"]))
        let empty = try tiles(Fx.adminDashboard(period: ["consumed": "0", "pct": "0"]))
        let noTick = try tiles(Fx.adminDashboard(top: ["notice_thresholds": ["1.00"]]))

        let full = try #require(try tile(.cycle, over).bar)
        #expect(full.fraction == 1)
        #expect(full.isOver)
        let none = try #require(try tile(.cycle, empty).bar)
        #expect(none.fraction == 0)
        #expect(none.tick == nil)
        #expect(try tile(.cycle, noTick).bar?.tick == nil)
    }

    @Test func theTickIsTheLowestThresholdUnderOneHundredPercent() throws {
        let list = try tiles(Fx.adminDashboard(top: ["notice_thresholds": ["1.00", "0.625", "0.9"]]))
        let bar = try #require(try tile(.cycle, list).bar)

        #expect(bar.tick == 0.63)
        #expect(bar.tickLabel == "Notice at 63%")
    }

    @Test func theCycleBySizeNoteNeedsTheMaxBasis() throws {
        let list = try tiles(Fx.adminDashboard(period: ["basis": "credits"]))

        #expect(try tile(.cycle, list).note == nil)
    }

    @Test func theIncludedLineIsLeftOutWhenTheDaysDoNotAddUp() throws {
        // Dopo un cambio di piano nel ciclo: 175 × 30 non fa 5000.
        let list = try tiles(Fx.adminDashboard(period: ["included": "5000"]))

        #expect(try tile(.included, list).sub == nil)
        #expect(try tile(.included, list).value == "5,000")
    }

    @Test func aPoolHasItsOwnLines() throws {
        let list = try tiles(Fx.adminDashboard(top: ["mode": "pool"]))

        #expect(try tile(.today, list).sub == "Drawn from the monthly credit pool")
        #expect(try tile(.included, list).sub == "Monthly credit pool, set in your contract")
    }

    @Test func theFreeTrialHasItsOwnLinesAndNeverBillsExtraCredits() throws {
        let board = try Fx.adminDashboard(period: ["included": "750"], top: Fx.trialTop)
        let list = try tiles(board)

        #expect(try tile(.today, list).sub == "25 a day for your one user")
        #expect(try tile(.included, list).sub == "25 a day × 30 trial days")
        #expect(try tile(.extra, list).sub == "Never billed during the trial")
    }

    @Test func todayWithoutAReadingIsADashNotZero() throws {
        let board = try Fx.adminDashboard(top: ["today": NSNull()])
        let today = try tile(.today, tiles(board))

        #expect(today.value == "—")
        #expect(today.unit == "")
    }

    @Test func theTodayLineFallsBackThroughTheDailyChain() throws {
        let noUsers = ["per_user_credits": NSNull(), "billed_users": NSNull()] as [String: Any?]
        let plan = try tiles(Fx.adminDashboard(top: noUsers))
        let none = try tiles(Fx.adminDashboard(period: ["included": NSNull()], top: noUsers), config: Fx.adminConfig(replacing: ["plan": NSNull()]))

        #expect(try tile(.today, plan).sub == "25 a day included")
        #expect(try tile(.today, none).sub == nil)
    }

    // MARK: Proiezione

    @Test func theProjectionWaitsForTheFirstFullDay() throws {
        let list = try tiles(Fx.adminDashboard(top: ["projection": NSNull()]))
        let projection = try tile(.projection, list)

        #expect(projection.value == "—")
        #expect(projection.unit == "")
        #expect(projection.sub == "Shown after the first full day")
        #expect(projection.sub2 == nil)
    }

    @Test func theProjectionWithinTheIncludedCreditsSaysSo() throws {
        let projection = try tile(.projection, tiles(Fx.adminDashboard(top: ["projection": Fx.withinProjection])))

        #expect(projection.value == "3,000")
        #expect(projection.sub == "by Nov 30 · within included")
        #expect(projection.sub2 == nil)
    }

    @Test func theProjectionHasASingularExtraCredit() throws {
        var one = Fx.withinProjection
        one["overage_credits"] = "1.04"
        one["overage_amount"] = "0.17"
        let projection = try tile(.projection, tiles(Fx.adminDashboard(top: ["projection": one])))

        #expect(projection.sub == "by Nov 30 · 1 extra credit")
    }

    @Test func theProjectedAmountIsHiddenUnderAZeroLimitAndOnTheTrial() throws {
        let zero = try tile(.projection, tiles(Fx.adminDashboard(period: ["extra_credits_billable": false])))
        let trial = try tile(.projection, tiles(Fx.adminDashboard(top: Fx.trialTop)))

        #expect(zero.sub2 == nil)
        #expect(trial.sub2 == nil)
        #expect(zero.sub == "by Nov 30 · 1,137.3 extra credits")
    }

    // MARK: Extra credits

    private func extra(_ period: [String: Any], top: [String: Any?] = [:], member: Bool = false) throws -> AdminUsageKPI {
        if member {
            let list = try tiles(Fx.memberDashboard(period: period, top: top), config: Fx.memberAdminConfig())
            return try tile(.extra, list)
        }
        return try tile(.extra, tiles(Fx.adminDashboard(period: period, top: top)))
    }

    @Test func extraCreditsInBillingShowTheAmountSoFarAndThePrice() throws {
        let owner = try extra(["overage_credits": "250.5", "overage_amount": "40.08"])

        #expect(owner.value == "250.5")
        #expect(owner.sub == "€40.08 so far · €0.16 each")
        #expect(owner.isExtra)
    }

    @Test func aClosedCycleSaysAtPriceEach() throws {
        let closed = ["overage_credits": "250.5", "overage_amount": "40.08", "closed": true, "start": "2026-10-01", "end": "2026-10-31"] as [String: Any]
        let list = try tiles(Fx.adminDashboard(period: closed, top: ["today": NSNull(), "projection": NSNull(), "week": NSNull()]))

        #expect(list.map(\.id) == [.cycle, .included, .extra])
        #expect(try tile(.cycle, list).label == "Cycle total")
        #expect(try tile(.extra, list).sub == "€40.08 at €0.16 each")
    }

    @Test func extraCreditsForEveryoneElseAreCreditsOnly() throws {
        let member = try extra(["overage_credits": "250.5"], member: true)
        let blind = try extra(["overage_credits": "250.5", "overage_amount": "40.08"], top: ["amounts_visible": false])
        let none = try extra([:], member: true)

        #expect(member.sub == "past the included credits")
        #expect(blind.sub == "past the included credits")
        #expect(none.sub == "None so far this cycle")
    }

    @Test func extraCreditsNotBilledAreAZeroLimitForAnOwnerWhoSeesMoney() throws {
        let positive = try extra(["overage_credits": "250.5", "extra_credits_billable": false])
        let zero = try extra(["extra_credits_billable": false])
        let member = try extra(["overage_credits": "250.5", "extra_credits_billable": false], member: true)

        #expect(positive.sub == "Not billed: limit €0")
        #expect(!positive.isExtra)
        // Il tile del ciclo lo dice solo quando ci sono extra; con zero extra legge il prezzo.
        #expect(zero.sub == "€0.16 per extra credit")
        #expect(member.sub == "past the included credits")
    }

    @Test func noPlanNeverBillsAndOnlyTheOwnerReadsWhy() throws {
        let top: [String: Any?] = ["tier_source": "unassigned_fallback", "amounts_visible": false]
        let owner = try extra(["overage_credits": "250.5"], top: top)
        let member = try extra(["overage_credits": "250.5"], top: top, member: true)
        let none = try extra([:], top: top)

        #expect(owner.sub == "Not billed: no plan assigned")
        #expect(member.sub == "past the included credits")
        #expect(none.sub == "None so far this cycle")
    }

    // MARK: Modo "day"

    private func dayBoard(_ period: [String: Any] = [:], top: [String: Any?] = [:]) throws -> AriaUsageDashboard {
        var all: [String: Any] = ["mode": "day", "today_included": "175", "today_consumed": "140",
                                  "today_overage_credits": "0", "today_overage_amount": "0"]
        all.merge(period) { _, new in new }
        return try Fx.adminDashboard(period: all, top: top)
    }

    @Test func dayModeHasFourTiles() throws {
        let list = try tiles(dayBoard())

        #expect(list.map(\.id) == [.today, .extraToday, .cycle, .extraCycle])
        let today = try tile(.today, list)
        #expect(today.value == "140")
        #expect(today.sub == "of 175 included today · 80%")
        #expect(today.note == "Resets at 00:00 UTC")
        #expect(today.bar == AdminUsageKPI.Bar(fraction: 0.8, isOver: false, tick: 0.7, tickLabel: "Notice at 70%"))
        #expect(try tile(.extraToday, list).label == "Extra credits today")
        #expect(try tile(.extraToday, list).sub == "€0.16 per extra credit")
        #expect(try tile(.cycle, list).value == "3,832.5")
        #expect(try tile(.cycle, list).sub == "2 days so far · 175 included each day")
        #expect(try tile(.extraCycle, list).label == "Extra credits this cycle")
    }

    @Test func dayModeTodayTurnsOverOnceItReachesTheDailyAllowance() throws {
        let list = try tiles(dayBoard(["today_consumed": "190", "today_overage_credits": "15", "today_overage_amount": "2.4"]))

        let bar = try #require(try tile(.today, list).bar)
        #expect(bar.isOver)
        #expect(bar.fraction == 1)
        #expect(try tile(.extraToday, list).sub == "€2.40 today · €0.16 each")
        #expect(try tile(.extraToday, list).isExtra)
    }

    @Test func dayModeExtraTilesForEveryoneElse() throws {
        let board = try dayBoard(["today_overage_credits": "15"])
        let member = try tiles(board, config: Fx.memberAdminConfig())

        #expect(try tile(.extraToday, member).sub == "past today's included credits")
        #expect(try tile(.extraCycle, member).sub == "None so far this cycle")
    }

    @Test func dayModeSaysNotBilledOnBothExtraTilesEvenAtZero() throws {
        let list = try tiles(dayBoard(["extra_credits_billable": false]))

        #expect(try tile(.extraToday, list).sub == "Not billed: limit €0")
        #expect(try tile(.extraCycle, list).sub == "Not billed: limit €0")
    }

    @Test func dayModeDropsTheTodayTileWhereTheMeterIsDrawn() throws {
        let list = try tiles(dayBoard(), allowance: Fx.adminAllowance())

        #expect(list.map(\.id) == [.extraToday, .cycle, .extraCycle])
    }
}

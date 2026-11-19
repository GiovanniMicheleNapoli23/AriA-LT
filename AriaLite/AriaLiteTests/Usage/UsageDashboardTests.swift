//
//  UsageDashboardTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  GET /v1/usage/dashboard: l'esempio del contratto (3.1), i valori di riposo di un server vecchio (sezione 8),
//  `by_agent` assente contro vuoto, le righe illeggibili scartate una a una e i decimali come stringa.
//

import Foundation
import Testing
@testable import AriaLite

@Suite("Usage dashboard")
struct UsageDashboardTests {
    private func d(_ text: String) -> Decimal { UsageFixture.d(text) }

    @Test func theContractExampleDecodes() throws {
        let board = try UsageFixture.dashboard()

        #expect(board.enabled)
        #expect(board.tier == "professional")
        #expect(board.tierSource == "assignment")
        #expect(board.currency == "EUR")
        #expect(board.amountsVisible)
        #expect(board.mode == .daily)
        #expect(board.state == .notice)
        #expect(board.todayCredits == d("38.4"))
        #expect(board.billedUsers == 7)
        #expect(board.perUserCredits == 25)
        #expect(board.noticeThresholds == [d("0.7"), 1])
        #expect(board.trial == nil)
        #expect(board.cycles == [.init(start: "2026-11-01", end: "2026-11-30"), .init(start: "2026-10-01", end: "2026-10-31")])
    }

    @Test func thePeriodIsTheAllowancePeriod() throws {
        let period = try #require(try UsageFixture.dashboard().period)

        #expect(period.mode == "cycle")
        #expect(period.start == "2026-11-01")
        #expect(period.end == "2026-11-30")
        #expect(period.includedDays == 30)
        #expect(period.included == 5250)
        #expect(period.creditsUsed == d("3015.0"))
        #expect(period.tokenEquivalent == d("3832.5"))
        #expect(period.consumed == d("3832.5"))
        #expect(period.pct == d("0.73"))
        // "0" è un importo (zero extra), `null` è nascosto: restano distinti.
        #expect(period.overageAmount == 0)
        #expect(period.todayIncluded == nil)
        #expect(period.pricePerCredit == d("0.16"))
        #expect(period.resetsAt == AriaDate.parse("2026-12-01T00:00:00Z"))
    }

    @Test func theWeekIsAMeterAndTheSpendCapHasItsOwnShape() throws {
        let board = try UsageFixture.dashboard()

        #expect(board.week?.used == d("412.5"))
        #expect(board.week?.included == 1225)
        #expect(board.week?.percent == 33)
        #expect(board.week?.resetsAt == AriaDate.parse("2026-11-23T00:00:00Z"))
        #expect(board.week?.warnThreshold == nil)
        #expect(board.spendCap?.amount == 500)
        #expect(board.spendCap?.creditsEquivalent == 3125)
        #expect(board.spendCap?.billed == 0)
        #expect(board.spendCap?.billedCredits == 0)
        #expect(board.spendCap?.percent == 0)
        #expect(board.spendCap?.status == .ok)
    }

    @Test func theSeriesKeepsTheDaysAsUTCStringsAndBothCreditCounts() throws {
        let series = try UsageFixture.dashboard().series

        #expect(series.map(\.day) == ["2026-11-01", "2026-11-18"])
        #expect(series[0].credits == d("96.0"))
        #expect(series[0].tokenEquivalent == d("131.2"))
        #expect(series[0].consumed == d("131.2"))
        #expect(series.allSatisfy { $0.inPeriod })
    }

    @Test func theBreakdownsKeepTheirRowsInOrder() throws {
        let board = try UsageFixture.dashboard()

        #expect(board.byActionType.map(\.key) == ["chat.reply", "rag.diagnostic"])
        #expect(board.byActionType[0].credits == d("2140.5"))
        #expect(board.byActionType[0].actions == 1712)
        #expect(board.byActionType[0].share == d("0.71"))
        #expect(board.byUser?.count == 1)
        #expect(board.byUser?.first?.key == "6720a1f0c2d94e0012ab34cd")
        #expect(board.byAgent?.map(\.key) == ["agent:general", "workflow:6b0c11aa90f3d90011ee7701"])
        #expect(board.byAgent?.last?.label == "Weekly line report")
        #expect(board.byAgent?.first?.label == nil)
    }

    @Test func theProjectionIsRead() throws {
        let projection = try #require(try UsageFixture.dashboard().projection)

        #expect(projection.until == "2026-11-30")
        #expect(projection.daysLeft == 12)
        #expect(projection.windowDays == 7)
        #expect(projection.dailyAverage == d("212.9"))
        #expect(projection.projected == d("6387.3"))
        #expect(projection.overageCredits == d("1137.3"))
        #expect(projection.overageAmount == d("181.97"))
    }

    // MARK: Un server vecchio

    @Test func anOlderServerLeavesTheNewPartsNil() throws {
        let board = try UsageFixture.dashboard(replacing: ["week": nil, "spend_cap": nil, "projection": nil, "trial": nil])

        #expect(board.week == nil)
        #expect(board.spendCap == nil)
        #expect(board.projection == nil)
        #expect(board.trial == nil)
        #expect(board.enabled)
    }

    @Test func anEmptyPayloadIsSafe() throws {
        let board = try UsageFixture.dashboard("{}")

        #expect(!board.enabled)
        #expect(!board.amountsVisible)
        #expect(board.period == nil)
        #expect(board.state == nil)
        #expect(board.mode == nil)
        #expect(board.todayCredits == nil)
        #expect(board.series.isEmpty)
        #expect(board.byActionType.isEmpty)
        #expect(board.byUser == nil)
        #expect(board.byAgent == nil)
        #expect(board.noticeThresholds.isEmpty)
        #expect(board.cycles.isEmpty)
    }

    @Test func aDisabledDashboardIsJustDisabled() throws {
        let board = try UsageFixture.dashboard(#"{"enabled": false, "period": null, "series": [], "by_action_type": [], "by_user": null, "by_agent": null, "cycles": []}"#)

        #expect(!board.enabled)
        #expect(board.period == nil)
        #expect(board.byAgent == nil)
    }

    @Test func aMemberHasNoAgentsAndAnOwnerWithNoAgentWorkHasAnEmptyList() throws {
        let member = try UsageFixture.dashboard(replacing: ["by_agent": NSNull()])
        let owner = try UsageFixture.dashboard(replacing: ["by_agent": [Any]()])
        let missing = try UsageFixture.dashboard(replacing: ["by_agent": nil])

        #expect(member.byAgent == nil)
        #expect(missing.byAgent == nil)
        #expect(owner.byAgent == [])
    }

    @Test func aClosedCycleHasNoTodayNoWeekAndNoProjection() throws {
        let board = try UsageFixture.dashboard(replacing: [
            "today": NSNull(), "week": NSNull(), "projection": NSNull(),
            "period": ["mode": "cycle", "start": "2026-10-01", "end": "2026-10-31", "closed": true, "included_days": 31],
        ])

        #expect(board.todayCredits == nil)
        #expect(board.week == nil)
        #expect(board.projection == nil)
        #expect(board.period?.start == "2026-10-01")
    }

    @Test func theTrialAndTheStateAreReused() throws {
        let board = try UsageFixture.dashboard(replacing: [
            "state": "capped", "tier_source": "unassigned_fallback",
            "trial": ["starts_on": "2026-11-10", "ends_on": "2026-11-24", "days_left": 6],
        ])

        #expect(board.state == .capped)
        #expect(board.trial == AriaUsageTrial(startsOn: "2026-11-10", endsOn: "2026-11-24", daysLeft: 6))
        #expect(board.tierSource == "unassigned_fallback")
    }

    // MARK: Elenchi tolleranti

    @Test func aBadRowIsDroppedNotThePayload() throws {
        let board = try UsageFixture.dashboard(replacing: [
            "series": [["day": "2026-11-17", "credits": "1"], ["credits": "2"], "oops", ["day": "2026-11-18", "credits": "3"]] as [Any],
            "by_action_type": ["nope", ["key": "chat.reply", "credits": "5", "actions": 2, "share": "1"], 7] as [Any],
            "by_user": [["key": "u1", "credits": "1"], [String: Any](), NSNull()] as [Any],
            "cycles": [["start": "2026-11-01", "end": "2026-11-30"], ["start": "2026-10-01"], "x"] as [Any],
        ])

        #expect(board.series.map(\.day) == ["2026-11-17", "2026-11-18"])
        #expect(board.byActionType.map(\.key) == ["chat.reply"])
        // Una riga vuota è ancora una riga ("Not attributed", senza cifre): solo ciò che non è un oggetto si scarta.
        #expect(board.byUser?.count == 2)
        #expect(board.cycles == [.init(start: "2026-11-01", end: "2026-11-30")])
        #expect(board.period != nil)
    }

    @Test func aMissingKeyIsNotAttributedAndAMissingShareStaysNil() throws {
        let board = try UsageFixture.dashboard(replacing: [
            "by_action_type": [["key": NSNull(), "credits": "0", "actions": 0, "share": NSNull()]] as [Any],
        ])
        let row = try #require(board.byActionType.first)

        #expect(row.key == nil)
        #expect(row.credits == 0)
        #expect(row.share == nil)
    }

    @Test func aSeriesDayOutsideThePeriodIsMarked() throws {
        let board = try UsageFixture.dashboard(replacing: [
            "series": [["day": "2026-11-09", "credits": "0", "in_period": false], ["day": "2026-11-10", "credits": "4"]] as [Any],
        ])

        #expect(board.series.map(\.inPeriod) == [false, true])
    }

    // MARK: Decimali

    @Test func decimalsComeAsStringsOrNumbersAndABadOneIsNilNotZero() throws {
        let board = try UsageFixture.dashboard(replacing: [
            "today": ["credits": "12a"],
            "per_user_credits": "25.5",
            "notice_thresholds": ["0.7", "oops", 1] as [Any],
            "series": [["day": "2026-11-18", "credits": 3.5, "token_equivalent": "x", "consumed": "0.1"]] as [Any],
            "spend_cap": ["amount": 250, "billed": NSNull(), "percent": 12.0, "status": "melting"],
        ])

        #expect(board.todayCredits == nil)
        #expect(board.perUserCredits == d("25.5"))
        #expect(board.noticeThresholds == [d("0.7"), 1])
        #expect(board.series.first?.credits == d("3.5"))
        #expect(board.series.first?.tokenEquivalent == nil)
        #expect(board.series.first?.consumed == d("0.1"))
        #expect(board.spendCap?.amount == 250)
        #expect(board.spendCap?.billed == nil)
        #expect(board.spendCap?.percent == 12)
        #expect(board.spendCap?.status == nil)
    }

    @Test func badTopLevelFieldsDoNotFailThePayload() throws {
        let board = try UsageFixture.dashboard(replacing: [
            "enabled": "yes", "mode": "hourly", "state": 3, "currency": 5, "period": "none", "billed_users": "many",
        ])

        #expect(!board.enabled)
        #expect(board.mode == nil)
        #expect(board.state == nil)
        #expect(board.currency == nil)
        #expect(board.period == nil)
        #expect(board.billedUsers == nil)
        #expect(board.series.count == 2)
    }
}

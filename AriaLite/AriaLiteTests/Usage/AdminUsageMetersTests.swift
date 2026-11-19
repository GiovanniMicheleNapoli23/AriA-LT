//
//  AdminUsageMetersTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Included credits" (contratto 3.5): quando c'è (stati del saldo), il tono di Today (ambra per quota esatta
//  contro soglia esatta, "over" da 100%), la tacca, i testi di Today e This week.
//

import Foundation
import Testing
@testable import AriaLite

private typealias Fx = UsageFixture

@Suite("Usage meters card")
struct AdminUsageMetersTests {
    private func allowance(today: [String: Any], week: [String: Any]? = nil) throws -> AriaAllowance {
        let weekMeter: [String: Any] = week ?? ["used": "20.5", "included": "280", "percent": 7, "resets_at": "2026-11-23T00:00:00Z"]
        return try Fx.adminAllowance(top: ["meters": ["today": today, "week": weekMeter]])
    }

    private func today(used: String, included: String = "40", percent: Int, warn: String? = "0.80") -> [String: Any] {
        var meter: [String: Any] = ["used": used, "included": included, "percent": percent, "resets_at": "2026-11-19T00:00:00Z"]
        if let warn { meter["warn_threshold"] = warn }
        return meter
    }

    private func meter(_ today: [String: Any]) throws -> AdminUsageMeter {
        let card = try #require(AdminUsageMetersBuilder.card(allowance(today: today), locale: Fx.english))
        return try #require(card.meters.first { $0.kind == .today })
    }

    // MARK: La scheda

    @Test func theCardHasTodayAndThisWeekWithTheirTexts() throws {
        let card = try #require(AdminUsageMetersBuilder.card(Fx.adminAllowance(), locale: Fx.english))

        #expect(card.title == "Included credits")
        #expect(card.description == "How much of your company's included credits is used, today and this week.")
        #expect(card.meters.map(\.kind) == [.today, .week])
        let today = card.meters[0]
        #expect(today.label == "Today")
        #expect(today.used == "12.4")
        #expect(today.ofIncluded == "of 40 credits")
        #expect(today.percentText == "31% used")
        #expect(today.fraction == 0.31)
        #expect(today.resetText == "Resets at 00:00 UTC")
        let week = card.meters[1]
        #expect(week.label == "This week")
        #expect(week.used == "20.5")
        #expect(week.ofIncluded == "of 280 credits")
        #expect(week.resetText == "Resets Mon, Nov 23 at 00:00 UTC")
    }

    @Test func theCardStatesFollowTheAllowance() throws {
        let owner = try Fx.adminFacts()
        let pool = try Fx.adminFacts(dashboard: Fx.adminDashboard(top: ["mode": "pool"]))
        let closed = try Fx.adminFacts(dashboard: Fx.adminDashboard(period: ["closed": true]))
        let read = try Fx.adminAllowance()
        let noMeters = try Fx.adminAllowance(top: ["meters": NSNull()])

        // Chiuso o pool: nessuna scheda, qualunque sia il saldo.
        #expect(AdminUsageMetersBuilder.state(closed, allowance: read, phase: .loaded, locale: Fx.english) == .hidden)
        #expect(AdminUsageMetersBuilder.state(pool, allowance: read, phase: .loaded, locale: Fx.english) == .hidden)
        // Il saldo si sta leggendo, è fallito, o non ha `meters`.
        #expect(AdminUsageMetersBuilder.state(owner, allowance: nil, phase: .loading, locale: Fx.english) == .loading)
        #expect(AdminUsageMetersBuilder.state(owner, allowance: nil, phase: .idle, locale: Fx.english) == .loading)
        #expect(AdminUsageMetersBuilder.state(owner, allowance: nil, phase: .failed, locale: Fx.english)
                == .failed(message: "Today's and this week's credits could not be loaded. Replies are not affected."))
        #expect(AdminUsageMetersBuilder.state(owner, allowance: noMeters, phase: .loaded, locale: Fx.english) == .hidden)
        // Letto con i contatori: la scheda.
        guard case .ready(let card) = AdminUsageMetersBuilder.state(owner, allowance: read, phase: .loaded, locale: Fx.english) else {
            Issue.record("expected the card")
            return
        }
        #expect(card.meters.count == 2)
    }

    @Test func noDashboardNoCard() throws {
        #expect(AdminUsageMetersBuilder.state(nil, allowance: try Fx.adminAllowance(), phase: .loaded) == .hidden)
    }

    // MARK: Tono di Today

    @Test func todayTurnsAmberFromTheExactThresholdNotTheRoundedPercent() throws {
        // 32 su 40 è esattamente 0.80.
        #expect(try meter(today(used: "32", percent: 80)).tone == .warning)
        // 31.99 su 40 sta sotto, anche se il suo 79% arrotondato e la soglia 80% sembrerebbero quasi pari.
        #expect(try meter(today(used: "31.99", percent: 79)).tone == .normal)
        // Una soglia frazionaria: 0.795 × 40 = 31.8. 31.9 la raggiunge, pur col 79% del server (arrotondato per difetto).
        #expect(try meter(today(used: "31.9", percent: 79, warn: "0.795")).tone == .warning)
        #expect(try meter(today(used: "31.7", percent: 79, warn: "0.795")).tone == .normal)
    }

    @Test func todayHasNoAmberWithoutAThreshold() throws {
        #expect(try meter(today(used: "39", percent: 97, warn: nil)).tone == .normal)
    }

    @Test func todayGoesOverAtOneHundredPercentAndSaysHowManyCreditsPast() throws {
        let over = try meter(today(used: "45.5", percent: 113))

        #expect(over.tone == .over)
        #expect(over.percentText == "113% used")
        // La barra si ferma piena.
        #expect(over.fraction == 1)
        #expect(over.overText == "5.5 credits past today's included")
        #expect(try meter(today(used: "41", percent: 102)).overText == "1 credit past today's included")
    }

    @Test func overIsDecidedByThePercentAndAtExactlyTheIncludedThereIsNothingPast() throws {
        let full = try meter(today(used: "40", percent: 100))

        #expect(full.tone == .over)
        #expect(full.overText == nil)
        #expect(full.fraction == 1)
    }

    @Test func theWeekNeverWarns() throws {
        let week = ["used": "270", "included": "280", "percent": 96, "resets_at": "2026-11-23T00:00:00Z", "warn_threshold": "0.5"] as [String: Any]
        let card = try #require(AdminUsageMetersBuilder.card(allowance(today: today(used: "1", percent: 2), week: week), locale: Fx.english))
        let meter = try #require(card.meters.first { $0.kind == .week })

        #expect(meter.tone == .normal)
        #expect(meter.tick == nil)
        #expect(meter.overText == nil)
    }

    // MARK: Tacca

    @Test func theTickSitsAtTheWarnThresholdOnceSomethingIsUsed() throws {
        let used = try meter(today(used: "5", percent: 12))
        let empty = try meter(today(used: "0", percent: 0))
        let fractional = try meter(today(used: "5", percent: 12, warn: "0.625"))

        #expect(used.tick == 0.8)
        #expect(used.tickLabel == "Notice at 80%")
        #expect(empty.tick == nil)
        #expect(fractional.tickLabel == "Notice at 62.5%")
    }

    @Test func aMeterWithAFigureMissingIsDropped() throws {
        let broken: [String: Any] = ["used": "5", "included": NSNull(), "percent": 12]
        let card = try #require(AdminUsageMetersBuilder.card(allowance(today: broken), locale: Fx.english))

        #expect(card.meters.map(\.kind) == [.week])
    }
}

//
//  AdminUsageChartTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I dati del grafico (contratto 3.6): totale corrente per giorno, conteggio a dimensione, proiezione fino a
//  `projection.until`, linea degli inclusi e dell'avviso, parte "over" di ogni barra, modo "day", descrizioni, testo
//  vuoto. Oggi è l'ultimo giorno di `series`.
//

import Foundation
import Testing
@testable import AriaLite

private typealias Fx = UsageFixture

@Suite("Usage chart data")
struct AdminUsageChartTests {
    private func series(_ rows: [(String, String, String, String)], inPeriod: Bool = true) -> [[String: Any]] {
        rows.map { ["day": $0.0, "consumed": $0.1, "token_equivalent": $0.2, "credits": $0.3, "in_period": inPeriod] }
    }

    /// Cinque giorni di ciclo, tre giorni di dati, proiezione fino al quinto con 10 al giorno.
    private func cycleBoard(period: [String: Any] = [:], top: [String: Any?] = [:]) throws -> AriaUsageDashboard {
        var allPeriod: [String: Any] = ["start": "2026-11-01", "end": "2026-11-05", "included": "120", "included_days": 5,
                                        "consumed": "180", "credits_used": "180", "token_equivalent": "180", "basis": "credits"]
        allPeriod.merge(period) { _, new in new }
        var all: [String: Any?] = [
            "series": series([("2026-11-01", "100", "120", "90"), ("2026-11-02", "50", "60", "40"), ("2026-11-03", "30", "35", "25")]),
            "projection": ["until": "2026-11-05", "days_left": 2, "window_days": 7, "daily_average": "10", "projected": "200",
                           "overage_credits": "80", "overage_amount": "12.8"],
            "notice_thresholds": ["0.70", "1.00"],
        ]
        all.merge(top) { _, new in new }
        return try Fx.adminDashboard(period: allPeriod, top: all)
    }

    private func makeChart(_ board: AriaUsageDashboard) throws -> AdminUsageChart {
        AdminUsageChartBuilder.build(try Fx.adminFacts(dashboard: board))
    }

    // MARK: Modo ciclo

    @Test func theCycleChartIsARunningTotalWithAProjectionAndTheOverSplit() throws {
        let chart = try makeChart(cycleBoard())

        #expect(chart.points.map(\.day) == ["2026-11-01", "2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05"])
        #expect(chart.points.map(\.kind) == [.actual, .actual, .actual, .projected, .projected])
        #expect(chart.points.map(\.value) == [100, 150, 180, 190, 200])
        // La parte sopra gli inclusi (120) è "over".
        #expect(chart.points.map(\.base) == [100, 120, 120, 120, 120])
        #expect(chart.points.map(\.over) == [0, 30, 60, 70, 80])
        #expect(chart.points.map(\.isToday) == [false, false, true, false, false])
        #expect(chart.showsProjection)
        #expect(chart.projectionLegend == "Projection")
        #expect(chart.points.allSatisfy { $0.charged == nil })
    }

    @Test func theLinesAndTheirLabels() throws {
        let chart = try makeChart(cycleBoard())

        #expect(chart.included == 120)
        #expect(chart.includedLabel == "Included · 120")
        // La soglia più bassa sotto il 100% per gli inclusi: 0.70 × 120.
        #expect(chart.notice == 84)
        #expect(chart.noticeLabel == "Notice 70% · 84")
        #expect(chart.extraLegend == "Extra")
        #expect(chart.extraZone == "Extra credits")
        #expect(chart.usedLegend == "Used")
        #expect(chart.perActionLegend == nil)
    }

    @Test func aPoolNamesItsIncludedLine() throws {
        let chart = try makeChart(cycleBoard(top: ["mode": "pool"]))

        #expect(chart.includedLabel == "Pool · 120")
    }

    @Test func theNoticeLineWaitsForTheFirstCreditAndNeedsAThreshold() throws {
        let empty = try makeChart(cycleBoard(period: ["consumed": "0"], top: ["series": [Any]()]))
        let none = try makeChart(cycleBoard(top: ["notice_thresholds": ["1.00"]]))

        #expect(empty.notice == nil)
        #expect(empty.isEmpty)
        #expect(empty.emptyText == "No credits used yet this cycle.")
        #expect(none.notice == nil)
        #expect(none.noticeLabel == nil)
        #expect(!none.isEmpty)
    }

    @Test func countedBySizeUsesTheTokenEquivalentAndAddsThePerActionLine() throws {
        let chart = try makeChart(cycleBoard(period: ["basis": "max", "token_equivalent": "215"]))

        // Il totale corrente di `token_equivalent` (120, 180, 215), proiettato dalla media del server.
        #expect(chart.points.map(\.value) == [120, 180, 215, 225, 235])
        // Il totale corrente dei crediti addebitati (90, 130, 155) per la linea "Credits per action".
        #expect(chart.points.map(\.charged) == [90, 130, 155, nil, nil])
        #expect(chart.bySize)
        #expect(chart.usedLegend == "Counted by size")
        #expect(chart.perActionLegend == "Credits per action")
    }

    @Test func aDayOutsideThePeriodHasNoBarAndDoesNotAddToTheTotal() throws {
        var rows = series([("2026-11-01", "100", "120", "90")])
        rows.append(contentsOf: series([("2026-11-02", "999", "999", "999")], inPeriod: false))
        rows.append(contentsOf: series([("2026-11-03", "30", "35", "25")]))
        let chart = try makeChart(cycleBoard(top: ["series": rows]))

        #expect(chart.points.prefix(3).map(\.kind) == [.actual, .empty, .actual])
        #expect(chart.points.prefix(3).map(\.value) == [100, nil, 130])
        #expect(chart.points[1].base == 0)
        #expect(chart.points[1].over == 0)
    }

    @Test func noProjectionOnAClosedCycleAndNoTodayEither() throws {
        let chart = try makeChart(cycleBoard(period: ["closed": true]))

        #expect(!chart.showsProjection)
        #expect(chart.points.map(\.kind) == [.actual, .actual, .actual, .empty, .empty])
        #expect(chart.points.allSatisfy { !$0.isToday })
        #expect(chart.projectionLegend == nil)
    }

    @Test func noProjectionWithoutOneOrWithoutADailyAverage() throws {
        let none = try makeChart(cycleBoard(top: ["projection": NSNull()]))
        let noAverage = try makeChart(cycleBoard(top: ["projection": ["until": "2026-11-05", "projected": "200", "overage_credits": "80"]]))

        #expect(none.points.map(\.kind) == [.actual, .actual, .actual, .empty, .empty])
        #expect(noAverage.points.map(\.kind) == [.actual, .actual, .actual, .empty, .empty])
    }

    @Test func theProjectionStopsAtTheDayItGivesAndTodayIsNotTheDeviceDate() throws {
        let board = try cycleBoard(top: ["projection": ["until": "2026-11-04", "days_left": 1, "window_days": 7, "daily_average": "10",
                                                   "projected": "190", "overage_credits": "70", "overage_amount": "11.2"]])
        let chart = try makeChart(board)

        #expect(chart.points.map(\.kind) == [.actual, .actual, .actual, .projected, .empty])
        // Oggi è l'ultimo giorno della serie, qualunque data dica il Mac: il test non guarda mai la data di sistema.
        #expect(chart.points.first { $0.isToday }?.day == "2026-11-03")
    }

    @Test func withoutAnIncludedFigureThereIsNoLineNoSplitAndNoExtraLegend() throws {
        let chart = try makeChart(cycleBoard(period: ["included": NSNull()]))

        #expect(chart.included == nil)
        #expect(chart.includedLabel == nil)
        #expect(chart.notice == nil)
        #expect(chart.extraLegend == nil)
        #expect(chart.points.map(\.over) == [0, 0, 0, 0, 0])
        #expect(chart.points.map(\.base) == [100, 150, 180, 190, 200])
    }

    @Test func theAxisLabelsDays1_8_15_22And29() throws {
        let full = try Fx.adminFacts(dashboard: cycleBoard(period: ["start": "2026-11-01", "end": "2026-11-30"]))
        let chart = AdminUsageChartBuilder.build(full)
        let labelled = chart.points.compactMap { point in point.axisLabel.map { (point.day, $0) } }

        #expect(labelled.map(\.0) == ["2026-11-01", "2026-11-08", "2026-11-15", "2026-11-22", "2026-11-29"])
        #expect(labelled.map(\.1) == ["Nov 1", "Nov 8", "Nov 15", "Nov 22", "Nov 29"])
        #expect(chart.points.count == 30)
    }

    // MARK: Modo "day"

    private func dayBoard() throws -> AriaUsageDashboard {
        try cycleBoard(period: ["mode": "day", "today_included": "75", "today_consumed": "30"])
    }

    @Test func dayModeDrawsEachDaysOwnCreditsAgainstTheDailyLine() throws {
        let chart = try makeChart(dayBoard())

        #expect(chart.title == "Credits by day")
        #expect(chart.points.map(\.kind) == [.actual, .actual, .actual, .empty, .empty])
        #expect(chart.points.map(\.value) == [100, 50, 30, nil, nil])
        #expect(chart.points.map(\.over) == [25, 0, 0, 0, 0])
        #expect(chart.included == 75)
        #expect(chart.includedLabel == "Included each day · 75")
        // Una sola linea, e nessuna proiezione.
        #expect(chart.notice == nil)
        #expect(chart.noticeLabel == nil)
        #expect(!chart.showsProjection)
        #expect(chart.description == "Credits used each UTC day. Every day starts again at 00:00 UTC with 75 included; the part of a bar above that line is extra.")
    }

    // MARK: Parole

    @Test func theDescriptionsAndTitles() throws {
        let cycle = try makeChart(cycleBoard())
        let closed = try makeChart(cycleBoard(period: ["closed": true]))
        let noWindow = try AdminUsageChartBuilder.description(
            Fx.adminFacts(dashboard: cycleBoard(top: ["projection": NSNull()]), config: Fx.adminConfig(replacing: ["ui": NSNull()])))

        #expect(cycle.title == "Credits this cycle")
        #expect(cycle.description == "Running total by day. Lighter bars project the rest of the cycle from the last 7 days.")
        #expect(closed.description == "Running total by day. Final figures.")
        #expect(noWindow == "Running total by day.")
    }

    @Test func theAccessibilityLabelsNameTheMonthAndTheFigures() throws {
        let plain = try makeChart(cycleBoard())
        let bySize = try makeChart(cycleBoard(period: ["basis": "max", "token_equivalent": "215"]))
        let day = try makeChart(dayBoard())

        #expect(plain.accessibilityLabel == "Running credit total for November 2026: 180 used of 120 included")
        #expect(bySize.accessibilityLabel == "Running credit total for November 2026: 180 counted by size, 180 per action, of 120 included")
        #expect(day.accessibilityLabel == "Credits used each day in November 2026, against 75 included each day")
    }
}

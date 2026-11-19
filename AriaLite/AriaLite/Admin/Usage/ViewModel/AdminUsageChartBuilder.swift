//
//  AdminUsageChartBuilder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I dati del grafico dei crediti (contratto 3.6, `credits-chart.tsx` della web). Modo ciclo: totale corrente per giorno,
//  giorni futuri proiettati con la media del server, linea degli inclusi e dell'avviso. Modo "day": i crediti di ogni
//  giorno contro i crediti inclusi di ogni giorno, senza proiezione. Oggi è l'ultimo giorno di `series`.
//

import Foundation

nonisolated enum AdminUsageChartBuilder {
    /// I giorni del mese con l'etichetta sull'asse.
    private static let labelDays: Set<Int> = [1, 8, 15, 22, 29]

    static func build(_ f: AdminUsageFacts) -> AdminUsageChart {
        let locale = f.locale
        let dayMode = f.dayMode
        let projection = (f.closed || dayMode) ? nil : f.dashboard.projection
        let included: Decimal? = dayMode ? f.todayDaily : f.period.included
        let isEmpty = f.period.consumed == 0
        let bars = points(f, included: included, projection: projection)

        let includedLabel = included.map { value -> String in
            let text = f.credits(value)
            if dayMode { return String(localized: "Included each day · \(text)") }
            return f.pool ? String(localized: "Pool · \(text)") : String(localized: "Included · \(text)")
        }
        var notice: Decimal?
        var noticeLabel: String?
        // Una sola linea in modo "day" (contratto 3.6); la linea dell'avviso aspetta il primo credito.
        if !dayMode, !isEmpty, let included, let share = f.noticeShare {
            let value = included * share
            notice = value
            let pct = f.whole(AdminUsageFormat.percent(share))
            let figure = AdminUsageFormat.whole(value, locale: locale)
            noticeLabel = String(localized: "Notice \(pct)% · \(figure)")
        }
        return AdminUsageChart(
            title: dayMode ? String(localized: "Credits by day") : String(localized: "usage.chart.title", defaultValue: "Credits this cycle"),
            description: description(f),
            points: bars,
            included: included.map(double),
            includedLabel: includedLabel,
            notice: notice.map(double),
            noticeLabel: noticeLabel,
            bySize: f.bySize,
            showsProjection: bars.contains { $0.kind == .projected },
            isEmpty: isEmpty,
            emptyText: String(localized: "No credits used yet this cycle."),
            accessibilityLabel: accessibilityLabel(f, included: included),
            usedLegend: f.bySize ? String(localized: "Counted by size") : String(localized: "usage.chart.used", defaultValue: "Used"),
            perActionLegend: f.bySize ? String(localized: "Credits per action") : nil,
            extraLegend: included == nil ? nil : String(localized: "usage.chart.extra", defaultValue: "Extra"),
            extraZone: String(localized: "usage.chart.extraZone", defaultValue: "Extra credits"),
            projectionLegend: bars.contains { $0.kind == .projected } ? String(localized: "usage.chart.projection", defaultValue: "Projection") : nil)
    }

    // MARK: Punti

    static func points(_ f: AdminUsageFacts, included: Decimal?, projection: AriaUsageProjection?) -> [AdminUsageChartPoint] {
        let byDay = Dictionary(f.dashboard.series.map { ($0.day, $0) }, uniquingKeysWith: { _, last in last })
        let last = f.dashboard.series.last?.day
        var running: Decimal = 0
        var runningCharged: Decimal = 0
        var after = 0
        return AdminUsageFormat.days(inCycleFrom: f.start, to: f.end).map { iso -> AdminUsageChartPoint in
            let today = !f.closed && iso == last
            let label = labelDays.contains(Int(iso.suffix(2)) ?? 0) ? AdminUsageFormat.shortDay(iso, locale: f.locale) : nil
            func point(_ kind: AdminUsageChartPoint.Kind, _ value: Decimal?, charged: Decimal? = nil) -> AdminUsageChartPoint {
                makePoint(day: iso, kind: kind, value: value, charged: charged, included: included, today: today, label: label)
            }
            if let entry = byDay[iso] {
                // Un giorno fuori dal periodo (nella prova) non ha barra.
                guard entry.inPeriod else { return point(.empty, nil) }
                if f.dayMode { return point(.actual, entry.consumed ?? 0) }
                running += (f.bySize ? entry.tokenEquivalent : entry.consumed) ?? 0
                runningCharged += entry.credits ?? 0
                return point(.actual, running, charged: f.bySize ? runningCharged : nil)
            }
            // Un giorno dopo oggi: la media giornaliera del server porta avanti il totale.
            if !f.dayMode, let projection, let average = projection.dailyAverage, let last, let until = projection.until,
               iso > last, iso <= until {
                after += 1
                return point(.projected, running + average * Decimal(after))
            }
            return point(.empty, nil)
        }
    }

    private static func makePoint(day: String, kind: AdminUsageChartPoint.Kind, value: Decimal?, charged: Decimal?,
                                  included: Decimal?, today: Bool, label: String?) -> AdminUsageChartPoint {
        guard let value else {
            return AdminUsageChartPoint(day: day, kind: kind, value: nil, base: 0, over: 0, charged: nil, isToday: today,
                                        axisLabel: label)
        }
        let base = included.map { min(value, $0) } ?? value
        let over = included.map { max(0, value - $0) } ?? 0
        return AdminUsageChartPoint(day: day, kind: kind, value: double(value), base: double(base), over: double(over),
                                    charged: charged.map(double), isToday: today, axisLabel: label)
    }

    // MARK: Parole

    /// "Running total by day. Lighter bars project the rest of the cycle from the last {n} days.", la versione finale
    /// su un ciclo chiuso, e quella del modo "day".
    static func description(_ f: AdminUsageFacts) -> String {
        if f.closed { return String(localized: "Running total by day. Final figures.") }
        if f.dayMode {
            guard let daily = f.todayDaily.map(f.credits) else {
                return String(localized: "Credits used each UTC day. Every day starts again at 00:00 UTC.")
            }
            return String(localized: "Credits used each UTC day. Every day starts again at 00:00 UTC with \(daily) included; the part of a bar above that line is extra.")
        }
        guard let window = f.config.projectionWindowDays ?? f.dashboard.projection?.windowDays else {
            return String(localized: "Running total by day.")
        }
        let days = f.whole(window)
        return String(localized: "Running total by day. Lighter bars project the rest of the cycle from the last \(days) days.")
    }

    private static func accessibilityLabel(_ f: AdminUsageFacts, included: Decimal?) -> String {
        let month = f.monthName
        let includedText = f.credits(included ?? 0)
        if f.dayMode {
            let daily = f.credits(f.todayDaily ?? 0)
            return String(localized: "Credits used each day in \(month), against \(daily) included each day")
        }
        let used = f.credits(f.period.consumed ?? 0)
        if f.bySize {
            let charged = f.credits(f.period.creditsUsed ?? 0)
            return String(localized: "Running credit total for \(month): \(used) counted by size, \(charged) per action, of \(includedText) included")
        }
        return String(localized: "Running credit total for \(month): \(used) used of \(includedText) included")
    }

    private static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}

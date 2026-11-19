//
//  AdminUsageKPIBuilder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le tessere delle cifre (contratto 3.4, `kpi-model.ts` della web): ciclo, con Today, This cycle, Included, Projection
//  ed Extra credits; modo "day", con quattro tessere. Una riga che direbbe una cifra non mandata si tralascia; gli euro
//  li legge solo un titolare che vede i soldi. Dove il contatore Today è disegnato la tessera Today sparisce.
//

import Foundation

nonisolated enum AdminUsageKPIBuilder {
    static func build(_ f: AdminUsageFacts) -> [AdminUsageKPI] {
        let kpis = f.dayMode ? dayKPIs(f) : cycleKPIs(f)
        return f.metersDrawn ? kpis.filter { $0.id != .today } : kpis
    }

    /// "credits".
    static var unit: String { String(localized: "usage.credits.unit", defaultValue: "credits") }

    // MARK: Modo ciclo

    private static func cycleKPIs(_ f: AdminUsageFacts) -> [AdminUsageKPI] {
        var kpis: [AdminUsageKPI] = []
        if !f.closed { kpis.append(todayTile(f)) }
        kpis.append(cycleTile(f))
        kpis.append(includedTile(f))
        if !f.closed { kpis.append(projectionTile(f)) }
        if f.trial != nil {
            kpis.append(figure(.extra, String(localized: "usage.kpi.extra", defaultValue: "Extra credits"),
                               f.period.overageCredits, f, sub: String(localized: "Never billed during the trial")))
        } else {
            kpis.append(extra(f, label: String(localized: "usage.kpi.extra", defaultValue: "Extra credits"), id: .extra,
                              value: f.period.overageCredits, amount: f.period.overageAmount,
                              kind: f.closed ? .closed : .cycle, notBilledAtZero: false))
        }
        return kpis
    }

    private static func todayTile(_ f: AdminUsageFacts) -> AdminUsageKPI {
        var sub: String?
        if f.pool {
            sub = String(localized: "Drawn from the monthly credit pool")
        } else if f.perUser, let perUser = f.dashboard.perUserCredits, let users = f.dashboard.billedUsers {
            let perUserText = f.credits(perUser)
            let count = f.whole(users)
            sub = users == 1
                ? String(localized: "\(perUserText) per user a day × \(count) user")
                : String(localized: "\(perUserText) per user a day × \(count) users")
        } else if let daily = f.daily.map(f.credits) {
            sub = f.trial != nil
                ? String(localized: "\(daily) a day for your one user")
                : String(localized: "\(daily) a day included")
        }
        return figure(.today, String(localized: "usage.kpi.today", defaultValue: "Today"), f.dashboard.todayCredits, f, sub: sub)
    }

    private static func cycleTile(_ f: AdminUsageFacts) -> AdminUsageKPI {
        let included = f.credits(f.included)
        let pct = f.whole(f.pct)
        let consumed = f.period.consumed
        var tile = figure(.cycle,
                          f.closed ? String(localized: "Cycle total") : String(localized: "usage.kpi.cycle", defaultValue: "This cycle"),
                          consumed, f, sub: String(localized: "of \(included) included · \(pct)%"))
        if consumed != nil {
            tile.bar = bar(fraction: Double(f.pct) / 100, over: f.included > 0 && (consumed ?? 0) >= f.included, f)
        }
        tile.note = f.bySize ? String(localized: "Long conversations count by size") : nil
        return tile
    }

    /// "{daily} a day × {days} days" solo quando daily × giorni è esattamente gli inclusi: dopo un cambio di piano nel
    /// ciclo i giorni non condividono una quota sola e la riga non tornerebbe.
    private static func includedTile(_ f: AdminUsageFacts) -> AdminUsageKPI {
        var sub: String?
        if f.pool {
            sub = String(localized: "Monthly credit pool, set in your contract")
        } else if let daily = f.daily, let count = f.period.includedDays, count > 0, daily * Decimal(count) == f.included {
            let dailyText = f.credits(daily)
            let days = f.whole(count)
            sub = f.trial != nil
                ? String(localized: "\(dailyText) a day × \(days) trial days")
                : String(localized: "\(dailyText) a day × \(days) days")
        }
        return figure(.included, String(localized: "usage.kpi.included", defaultValue: "Included"), f.period.included, f, sub: sub)
    }

    private static func projectionTile(_ f: AdminUsageFacts) -> AdminUsageKPI {
        let label = String(localized: "usage.kpi.projection", defaultValue: "Projection")
        guard let projection = f.dashboard.projection, let projected = projection.projected else {
            return AdminUsageKPI(id: .projection, label: label, value: "—", unit: "",
                                 sub: String(localized: "Shown after the first full day"))
        }
        var tile = figure(.projection, label, projected, f, sub: nil)
        let date = f.day(projection.until) ?? ""
        let over = projection.overageCredits ?? 0
        if over > 0 {
            // I crediti extra, arrotondati a un decimale come li scrive la web.
            let extraCredits = f.credits(over)
            tile.sub = AriaCredits.oneDecimal(over) == 1
                ? String(localized: "by \(date) · \(extraCredits) extra credit")
                : String(localized: "by \(date) · \(extraCredits) extra credits")
            // Sotto un tetto di 0 euro non si addebita niente: nessun importo proiettato.
            if f.textOwner, f.trial == nil, !f.capZero, let total = projection.overageAmount {
                let amount = f.amount(total)
                tile.sub2 = String(localized: "≈ \(amount) at this pace")
            }
        } else {
            tile.sub = String(localized: "by \(date) · within included")
        }
        return tile
    }

    // MARK: Modo "day"

    private static func dayKPIs(_ f: AdminUsageFacts) -> [AdminUsageKPI] {
        let today = f.period.todayConsumed ?? f.dashboard.todayCredits
        var todayTile = figure(.today, String(localized: "usage.kpi.today", defaultValue: "Today"), today, f, sub: nil)
        if let included = f.period.todayIncluded {
            let daily = f.credits(included)
            let pct = f.whole(f.dayPct)
            todayTile.sub = f.elide(String(localized: "of \(daily) included today · \(pct)%"))
        }
        todayTile.bar = bar(fraction: Double(f.dayPct) / 100,
                            over: f.period.todayIncluded != nil && today != nil && (today ?? 0) >= (f.period.todayIncluded ?? 0), f)
        todayTile.note = String(localized: "Resets at 00:00 UTC")

        var cycleTile = figure(.cycle, String(localized: "usage.kpi.cycle", defaultValue: "This cycle"), f.period.consumed, f, sub: nil)
        if let daily = f.todayDaily.map(f.credits) {
            let days = f.dashboard.series.filter(\.inPeriod).count
            let count = f.whole(days)
            cycleTile.sub = days == 1
                ? String(localized: "\(count) day so far · \(daily) included each day")
                : String(localized: "\(count) days so far · \(daily) included each day")
        }
        return [
            todayTile,
            extra(f, label: String(localized: "Extra credits today"), id: .extraToday, value: f.period.todayOverageCredits ?? 0,
                  amount: f.period.todayOverageAmount, kind: .today, notBilledAtZero: true),
            cycleTile,
            extra(f, label: String(localized: "Extra credits this cycle"), id: .extraCycle, value: f.period.overageCredits,
                  amount: f.period.overageAmount, kind: .cycle, notBilledAtZero: true),
        ]
    }

    // MARK: Pezzi comuni

    /// Una tessera con la sua cifra in crediti ("—" e niente unità se la cifra non c'è).
    private static func figure(_ id: AdminUsageKPI.ID, _ label: String, _ value: Decimal?, _ f: AdminUsageFacts,
                               sub: String?) -> AdminUsageKPI {
        guard let value else { return AdminUsageKPI(id: id, label: label, value: "—", unit: "", sub: nil) }
        return AdminUsageKPI(id: id, label: label, value: f.credits(value), unit: unit, sub: sub)
    }

    /// La barra: quota fino a 1, tacca del primo avviso sotto il 100% (`noticeShare`), che aspetta il primo credito.
    private static func bar(fraction: Double, over: Bool, _ f: AdminUsageFacts) -> AdminUsageKPI.Bar {
        let capped = min(1, max(0, fraction))
        var bar = AdminUsageKPI.Bar(fraction: capped, isOver: over)
        if let share = f.noticeShare, capped > 0 {
            let tick = AdminUsageFormat.percent(share)
            bar.tick = Double(tick) / 100
            let pct = f.whole(tick)
            bar.tickLabel = String(localized: "Notice at \(pct)%")
        }
        return bar
    }
}

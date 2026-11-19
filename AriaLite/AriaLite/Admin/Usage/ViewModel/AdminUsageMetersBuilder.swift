//
//  AdminUsageMetersBuilder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Today e This week (contratto 3.5, `usage-meters.tsx`). Today vira all'ambra quando la quota ESATTA (usati ÷ inclusi)
//  raggiunge la soglia esatta, non quando la percentuale arrotondata del server raggiunge una soglia arrotondata;
//  "over" da 100% in su. La barra si ferma piena.
//

import Foundation

nonisolated enum AdminUsageMetersBuilder {
    static var title: String { String(localized: "usage.meters.title", defaultValue: "Included credits") }
    static var description: String {
        String(localized: "How much of your company's included credits is used, today and this week.")
    }
    static var loadError: String {
        String(localized: "Today's and this week's credits could not be loaded. Replies are not affected.")
    }

    /// Lo stato della scheda. `facts` manca quando il cruscotto non c'è: nessuna scheda.
    static func state(_ f: AdminUsageFacts?, allowance: AriaAllowance?, phase: AdminUsagePhase,
                      locale: Locale = .autoupdatingCurrent) -> AdminUsageMetersState {
        // Un ciclo chiuso e un pool non hanno contatori.
        guard let f, !f.closed, !f.pool else { return .hidden }
        if let allowance {
            guard let ready = card(allowance, locale: locale) else { return .hidden }
            return .ready(ready)
        }
        switch phase {
        case .failed: return .failed(message: loadError)
        default: return .loading
        }
    }

    static func card(_ allowance: AriaAllowance, locale: Locale = .autoupdatingCurrent) -> AdminUsageMetersCard? {
        guard let meters = allowance.meters else { return nil }
        var list: [AdminUsageMeter] = []
        if let today = meters.today, let meter = todayMeter(today, locale: locale) { list.append(meter) }
        if let week = meters.week, let meter = weekMeter(week, locale: locale) { list.append(meter) }
        guard !list.isEmpty else { return nil }
        return AdminUsageMetersCard(title: title, description: description, meters: list)
    }

    // MARK: Contatori

    static func todayMeter(_ meter: AriaAllowance.Meter, locale: Locale = .autoupdatingCurrent) -> AdminUsageMeter? {
        guard let used = meter.used, let included = meter.included, let percent = meter.percent else { return nil }
        let tone: AdminUsageTone
        if percent >= 100 {
            tone = .over
        } else if let warn = meter.warnThreshold, reachesThreshold(used: used, included: included, percent: percent, warn: warn) {
            tone = .warning
        } else {
            tone = .normal
        }
        var result = base(.today, label: String(localized: "usage.kpi.today", defaultValue: "Today"), meter,
                          used: used, included: included, percent: percent, tone: tone, locale: locale)
        result.resetText = String(localized: "Resets at 00:00 UTC")
        if let warn = meter.warnThreshold, used > 0 {
            result.tick = min(1, max(0, NSDecimalNumber(decimal: warn).doubleValue))
            let pct = AdminUsageFormat.thresholdPercent(warn, locale: locale)
            result.tickLabel = String(localized: "Notice at \(pct)%")
        }
        let past = used - included
        if tone == .over, past > 0 {
            let credits = AdminUsageFormat.credits(past, locale: locale)
            result.overText = AriaCredits.oneDecimal(past) == 1
                ? String(localized: "\(credits) credit past today's included")
                : String(localized: "\(credits) credits past today's included")
        }
        return result
    }

    static func weekMeter(_ meter: AriaAllowance.Meter, locale: Locale = .autoupdatingCurrent) -> AdminUsageMeter? {
        guard let used = meter.used, let included = meter.included, let percent = meter.percent else { return nil }
        var result = base(.week, label: String(localized: "This week"), meter, used: used, included: included,
                          percent: percent, tone: .normal, locale: locale)
        if let resets = meter.resetsAt {
            let date = AdminUsageFormat.weekDay(resets, locale: locale)
            result.resetText = String(localized: "Resets \(date) at 00:00 UTC")
        }
        return result
    }

    /// La quota esatta contro la soglia esatta, in `Decimal` (niente divisione né arrotondamenti in virgola mobile):
    /// usati ≥ inclusi × soglia. Senza crediti inclusi si sa solo la percentuale del server: si confronta per difetto.
    static func reachesThreshold(used: Decimal, included: Decimal, percent: Int, warn: Decimal) -> Bool {
        if included > 0 { return used >= included * warn }
        return percent >= AriaCredits.wholePart(warn * 100)
    }

    private static func base(_ kind: AdminUsageMeter.Kind, label: String, _ meter: AriaAllowance.Meter, used: Decimal,
                             included: Decimal, percent: Int, tone: AdminUsageTone, locale: Locale) -> AdminUsageMeter {
        let usedText = AdminUsageFormat.credits(used, locale: locale)
        let includedText = AdminUsageFormat.credits(included, locale: locale)
        let pct = AdminUsageFormat.whole(percent, locale: locale)
        return AdminUsageMeter(
            kind: kind, label: label, used: usedText,
            ofIncluded: String(localized: "of \(includedText) credits"),
            percentText: AdminUsageFormat.elide(String(localized: "\(pct)% used"), locale: locale),
            fraction: min(1, max(0, Double(percent) / 100)), tone: tone)
    }
}

//
//  AdminUsageHeadingBuilder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'intestazione "{plan} · {month} cycle", la riga dei fatti e il selettore del ciclo (contratto 3.2, `CycleHeading` e
//  `CyclePicker` della web). Oggi è l'ultimo giorno di `series`, mai la data del telefono.
//

import Foundation

nonisolated enum AdminUsageHeadingBuilder {
    static func build(_ f: AdminUsageFacts) -> AdminUsageHeading {
        // La prova si chiama col suo nome, mai "Free Demo plan"; solo sul ciclo corrente.
        let key = f.dashboard.tier ?? f.config.plan?.tier ?? ""
        let plan = f.trial != nil ? AdminUsageWords.planName("free_demo") : AdminUsageWords.planName(key)
        let month = f.monthName
        let cycle = String(localized: "\(month) cycle")
        let title = plan.isEmpty ? cycle : String(localized: "usage.heading.title", defaultValue: "\(plan) · \(cycle)")
        return AdminUsageHeading(plan: plan, cycle: cycle, title: title, facts: facts(f))
    }

    /// "{start} – {end}", l'azzeramento e i giorni che restano.
    static func facts(_ f: AdminUsageFacts) -> [String] {
        let start = f.day(f.start) ?? f.start
        let end = f.day(f.end) ?? f.end
        var parts = [String(localized: "\(start) – \(end)")]
        if f.closed {
            parts.append(String(localized: "Closed (UTC)"))
        } else if f.dayMode {
            parts.append(String(localized: "Daily credits reset at 00:00 UTC"))
        } else {
            let reset = f.reset
            parts.append(String(localized: "Resets \(reset), 00:00 UTC"))
        }
        if let left = daysLeft(f) {
            let count = f.whole(left)
            parts.append(left == 0
                ? String(localized: "Last day")
                : left == 1 ? String(localized: "\(count) day left") : String(localized: "\(count) days left"))
        }
        return parts
    }

    /// I giorni interi dopo oggi prima dell'azzeramento (0 l'ultimo giorno), solo sul ciclo corrente e solo se oggi è
    /// dentro il ciclo. Oggi è l'ultimo giorno di `series`: senza serie non c'è un giorno del server e la frase si tralascia.
    static func daysLeft(_ f: AdminUsageFacts) -> Int? {
        guard !f.closed, let today = f.todayDay, today >= f.start, today <= f.end else { return nil }
        return AdminUsageFormat.days(from: today, to: f.end)
    }

    // MARK: Selettore

    /// I cicli del selettore, dal più recente, dalla risposta del ciclo CORRENTE; senza elenco, il ciclo corrente da solo.
    /// Il ciclo che comincia come `currentStart` si legge "{month} · current cycle".
    static func options(cycles: [AriaUsageDashboard.Cycle], current: AriaUsageDashboard.Cycle?,
                        locale: Locale = .autoupdatingCurrent) -> [AdminUsageCycleOption] {
        let list = cycles.isEmpty ? (current.map { [$0] } ?? []) : cycles
        return list.map { cycle in
            let month = AdminUsageFormat.monthYear(cycle.start, locale: locale) ?? cycle.start
            let isCurrent = cycle.start == current?.start
            return AdminUsageCycleOption(
                cycle: cycle, title: isCurrent ? String(localized: "\(month) · current cycle") : month, isCurrent: isCurrent)
        }
    }
}

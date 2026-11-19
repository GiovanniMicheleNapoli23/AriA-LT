//
//  AdminUsageBreakdownBuilder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  "Where credits went" (contratto 3.7, `breakdown-model.ts` della web). Per azione per tutti; per utente e per
//  agente per un titolare (l'agente solo se `by_agent` non è `null`); un membro legge "Your usage", la propria riga.
//  Ogni riga ha un nome, i crediti e una barra per la sua quota.
//

import Foundation

nonisolated enum AdminUsageBreakdownBuilder {
    static func build(_ f: AdminUsageFacts, people: AdminUsagePeople) -> AdminUsageBreakdown {
        let dashboard = f.dashboard
        var columns = [AdminUsageBreakdownColumn(
            kind: .action, title: String(localized: "By action"),
            rows: dashboard.byActionType.enumerated().map { index, row in
                makeRow(f, row, index: index, name: AdminUsageWords.actionName(row.key))
            })]
        if f.owner {
            columns.append(AdminUsageBreakdownColumn(
                kind: .user, title: String(localized: "By user"),
                rows: (dashboard.byUser ?? []).enumerated().map { index, row in userRow(f, row, index: index, people: people) }))
            if let agents = dashboard.byAgent {
                columns.append(AdminUsageBreakdownColumn(
                    kind: .agent, title: String(localized: "By agent"),
                    rows: agents.enumerated().map { index, row in
                        makeRow(f, row, index: index, name: AdminUsageWords.agentName(key: row.key, label: row.label))
                    }))
            }
        } else {
            columns.append(AdminUsageBreakdownColumn(
                kind: .yours, title: String(localized: "Your usage"),
                rows: (dashboard.byUser ?? []).enumerated().map { index, row in
                    let pct = f.whole(AdminUsageFormat.percent(share(f, row)))
                    return userRow(f, row, index: index, people: people,
                                   note: String(localized: "\(pct)% of the company's credits"))
                },
                foot: String(localized: "Owners see every user and agent.")))
        }
        return AdminUsageBreakdown(
            title: String(localized: "Where credits went"), description: description(f), note: note(f), columns: columns,
            emptyText: String(localized: "Nothing to show yet."))
    }

    // MARK: Descrizione

    static func description(_ f: AdminUsageFacts) -> String {
        let month = f.monthName
        switch (f.closed, f.owner) {
        case (true, true): return String(localized: "In \(month), by what was done, who did it and which agent ran it.")
        case (true, false): return String(localized: "In \(month), by what was done, and your own usage.")
        case (false, true): return String(localized: "This cycle, by what was done, who did it and which agent ran it.")
        case (false, false): return String(localized: "This cycle, by what was done, and your own usage.")
        }
    }

    /// Il ciclo contato a dimensione: le righe contano i crediti addebitati per azione, "This cycle" i consumati.
    static func note(_ f: AdminUsageFacts) -> String? {
        guard f.bySize, let charged = f.period.creditsUsed, let counted = f.period.consumed else { return nil }
        let chargedText = f.credits(charged)
        let consumed = f.credits(counted)
        return String(localized: "These rows count credits per action: \(chargedText) in all. Long conversations count by size, so “This cycle” shows \(consumed).")
    }

    // MARK: Righe

    /// La quota di una riga come frazione 0…100: `share` × 100, altrimenti crediti ÷ crediti addebitati (0 se non c'è nulla).
    private static func share(_ f: AdminUsageFacts, _ row: AriaUsageDashboard.Row) -> Decimal {
        if let share = row.share { return share }
        guard let charged = f.period.creditsUsed, charged > 0, let credits = row.credits else { return 0 }
        return credits / charged
    }

    private static func makeRow(_ f: AdminUsageFacts, _ row: AriaUsageDashboard.Row, index: Int, name: String,
                                pending: Bool = false, note: String? = nil) -> AdminUsageBreakdownRow {
        let fraction = NSDecimalNumber(decimal: share(f, row)).doubleValue
        return AdminUsageBreakdownRow(
            // Due righe senza chiave non devono avere lo stesso id.
            id: row.key.map { "key:\($0)" } ?? "unkeyed:\(index)",
            name: name, isPending: pending,
            credits: row.credits.map(f.credits) ?? "—",
            fraction: min(1, max(0, fraction)), note: note)
    }

    private static func userRow(_ f: AdminUsageFacts, _ row: AriaUsageDashboard.Row, index: Int, people: AdminUsagePeople,
                                note: String? = nil) -> AdminUsageBreakdownRow {
        guard let key = row.key else {
            return makeRow(f, row, index: index, name: AdminUsageWords.notAttributed, note: note)
        }
        let person = people.name(for: key)
        let label: String
        switch person {
        case .name(let name) where people.isYou(key):
            label = String(localized: "\(name) (you)")
        default:
            label = person.text ?? ""
        }
        return makeRow(f, row, index: index, name: label, pending: person.isPending, note: note)
    }
}

//
//  AdminUsageSpendCapHistoryBuilder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Lo storico del limite (contratto 5.2, `spend-cap-history.tsx` della web): una riga per modifica, la più recente per
//  prima. I nomi vengono dai membri della pagina; finché non sono letti le righe restano segnaposto, così nessuno
//  compare un attimo come "Former member". `set_by: null` è l'assistenza AriA.
//

import Foundation

nonisolated enum AdminUsageSpendCapHistoryBuilder {
    /// - `changes`: le righe del server (già dalla più recente).
    /// - `person`: il nome di chi ha salvato (`AdminUsageViewModel.personName`).
    static func card(changes: [AriaSpendCapChange], phase: AdminUsagePhase, currency: String, locale: Locale,
                     person: (String?) -> AdminUsagePersonName) -> AdminUsageSpendCapHistoryCard {
        let title = String(localized: "usage.history.title", defaultValue: "Limit history")
        let description = String(localized: "Every change to the spending limit, newest first.")
        func make(_ content: AdminUsageSpendCapHistoryCard.Content) -> AdminUsageSpendCapHistoryCard {
            AdminUsageSpendCapHistoryCard(title: title, description: description, content: content)
        }
        if changes.isEmpty {
            switch phase {
            case .idle, .loading:
                return make(.loading)
            case .failed:
                return make(.failed(String(localized: "The limit history could not be loaded. The limit in force still applies.")))
            case .loaded:
                return make(.empty(String(localized: "No changes yet. The limit in force has never been edited.")))
            }
        }
        let names = changes.map { person($0.setBy) }
        // Un nome ancora in lettura: tutta la tabella resta segnaposto.
        if names.contains(where: \.isPending) { return make(.loading) }
        let dash = "—"
        func money(_ value: Decimal?) -> String {
            value.map { AdminUsageFormat.money($0, currency: currency, locale: locale) } ?? dash
        }
        let rows = changes.indices.map { index -> AdminUsageSpendCapHistoryCard.Row in
            let change = changes[index]
            return AdminUsageSpendCapHistoryCard.Row(
                id: index,
                date: change.effectiveFrom.flatMap { AdminUsageFormat.dayWithYear(of: $0, locale: locale) } ?? dash,
                changedBy: names[index].text ?? dash,
                // Il chip "Owner" solo per chi ha salvato come titolare; l'assistenza AriA non ne ha.
                ownerChip: change.setBy != nil && change.setByRole == .owner
                    ? String(localized: "usage.notices.roleOwner", defaultValue: "Owner") : nil,
                oldLimit: money(change.previousAmount), newLimit: money(change.amount))
        }
        return make(.rows(rows))
    }
}

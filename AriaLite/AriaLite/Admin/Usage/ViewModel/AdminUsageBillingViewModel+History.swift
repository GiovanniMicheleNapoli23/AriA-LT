//
//  AdminUsageBillingViewModel+History.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Lo storico del limite (contratto 5.2): lettura e scheda. I nomi vengono dai membri della pagina; finché non sono letti le
//  righe restano segnaposto.
//

import Foundation

extension AdminUsageBillingViewModel {
    var historyCard: AdminUsageSpendCapHistoryCard? {
        guard let facts = page.facts else { return nil }
        // I nomi si costruiscono una volta: il costruttore puro non chiama la pagina.
        let people = page.people
        return AdminUsageSpendCapHistoryBuilder.card(
            changes: history, phase: historyPhase, currency: cap?.currency ?? facts.currency, locale: facts.locale,
            person: { people.name(for: $0) })
    }

    func loadHistory() async {
        let stamp = currentStamp()
        if history.isEmpty { historyPhase = .loading }
        do {
            let rows = try await api.spendCapHistory()
            guard isCurrent(stamp) else { return }
            history = rows
            historyPhase = .loaded
        } catch {
            guard isCurrent(stamp) else { return }
            if handle(error) {
                if history.isEmpty { historyPhase = .failed }
            } else if history.isEmpty {
                historyPhase = .idle
            }
        }
    }

    func retryHistory() async {
        historyPhase = .loading
        await loadHistory()
    }
}

//
//  AdminCraftedViewModel+Sessions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le sessioni concluse della pagina Crafted: filtro per verdetto, ricerca, riepilogo in cima.
//  Da una sessione si aprono la conversazione in sola lettura e il report Word.
//

import Foundation

extension AdminCraftedViewModel {
    /// I verdetti presenti, per il filtro ("" = senza verdetto).
    var verdicts: [String] {
        Set(sessions.map { $0.verdict?.lowercased() ?? "" }).sorted()
    }

    var verdictFilterLabel: String {
        verdictFilter.map { AdminCraftedVerdict.label($0.isEmpty ? nil : $0) } ?? String(localized: "All verdicts")
    }

    func verdictLabel(_ verdict: String) -> String { AdminCraftedVerdict.label(verdict.isEmpty ? nil : verdict) }

    /// Le più recenti in cima.
    var visibleSessions: [AdminCraftedSessionReview] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return sessions
            .filter { verdictFilter == nil || ($0.verdict?.lowercased() ?? "") == verdictFilter }
            .filter {
                query.isEmpty || [$0.displayTitle, $0.alarmCode ?? ""].contains { $0.localizedStandardContains(query) }
            }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    var sessionsSubtitle: String {
        let count = visibleSessions.count
        return String(localized: "\(count) sessions")
    }

    /// Le cifre del riepilogo del server; senza riepilogo, nessuna.
    var summaryTiles: [AdminCraftedSummaryTile] {
        guard let summary else { return [] }
        var tiles = [
            AdminCraftedSummaryTile(title: String(localized: "Sessions"), value: "\(summary.sessions ?? sessions.count)",
                                    systemImage: "bubble.left.and.text.bubble.right"),
            AdminCraftedSummaryTile(title: String(localized: "Awaiting review"), value: "\(summary.awaitingReview ?? 0)",
                                    systemImage: "hourglass"),
            AdminCraftedSummaryTile(title: String(localized: "Resolved"), value: "\(summary.resolved ?? 0)",
                                    systemImage: "checkmark.seal"),
        ]
        if let rating = summary.avgRating {
            tiles.append(AdminCraftedSummaryTile(title: String(localized: "Average rating"),
                                                 value: rating.formatted(.number.precision(.fractionLength(1))),
                                                 systemImage: "star"))
        }
        return tiles
    }

    var hasLocalFilters: Bool {
        switch tab {
        case .widgets: kindFilter != nil
        case .sessions: verdictFilter != nil
        }
    }

    func clearFilters() {
        switch tab {
        case .widgets: kindFilter = nil
        case .sessions: verdictFilter = nil
        }
    }
}

/// Una cifra del riepilogo delle sessioni.
struct AdminCraftedSummaryTile: Identifiable, Hashable {
    let title: String
    let value: String
    let systemImage: String

    var id: String { title }
}

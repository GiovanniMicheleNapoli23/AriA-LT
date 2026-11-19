//
//  AdminUsageBreakdown.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  "Where credits went" (contratto 3.7), già scritto: le colonne per ruolo, le righe con nome, crediti e barra, le
//  descrizioni.
//

import Foundation

nonisolated struct AdminUsageBreakdownRow: Sendable, Equatable, Identifiable {
    var id: String
    /// Il nome; vuoto finché `isPending` (la vista mette un segnaposto).
    var name: String
    var isPending: Bool
    /// I crediti, scritti.
    var credits: String
    /// La quota da 0 a 1: `share` × 100, oppure crediti ÷ crediti addebitati quando `share` manca.
    var fraction: Double
    /// Per "Your usage": "{pct}% of the company's credits".
    var note: String?
}

nonisolated struct AdminUsageBreakdownColumn: Sendable, Equatable, Identifiable {
    nonisolated enum Kind: Sendable, Equatable {
        case action, user, agent
        /// "Your usage": la propria riga di un membro.
        case yours
    }

    var kind: Kind
    var title: String
    var rows: [AdminUsageBreakdownRow]
    /// "Owners see every user and agent." sotto "Your usage".
    var foot: String?

    var id: Kind { kind }
}

nonisolated struct AdminUsageBreakdown: Sendable, Equatable {
    var title: String
    var description: String
    /// La nota del ciclo contato a dimensione ("These rows count credits per action: …").
    var note: String?
    var columns: [AdminUsageBreakdownColumn]
    /// "Nothing to show yet.": una colonna vuota lo dice.
    var emptyText: String
}

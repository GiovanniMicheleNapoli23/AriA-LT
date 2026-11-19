//
//  AdminUsageSpendCapHistoryCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Limit history" (contratto 5.2) già scritta: ogni riga è una modifica del limite, la più recente per prima.
//

import Foundation

nonisolated struct AdminUsageSpendCapHistoryCard: Sendable, Equatable {
    /// "Limit history".
    var title: String
    /// "Every change to the spending limit, newest first."
    var description: String
    var content: Content

    nonisolated enum Content: Sendable, Equatable {
        /// Segnaposto: lo storico o i membri (i nomi) si stanno leggendo, così nessuno compare come "Former member".
        case loading
        /// "The limit history could not be loaded. The limit in force still applies." e Riprova.
        case failed(String)
        /// "No changes yet. The limit in force has never been edited."
        case empty(String)
        case rows([Row])
    }

    nonisolated struct Row: Sendable, Equatable, Identifiable {
        var id: Int
        /// Il giorno UTC con l'anno.
        var date: String
        /// Il nome di chi l'ha cambiato, "AriA support", "Former member" o "Name unavailable".
        var changedBy: String
        /// Il chip "Owner": chi ha salvato aveva il ruolo di titolare.
        var ownerChip: String?
        /// "—" per il primo limite.
        var oldLimit: String
        /// "—" per una modifica che ha tolto il limite.
        var newLimit: String
    }

    /// Le intestazioni delle colonne, per le etichette di VoiceOver delle righe.
    var columns: [String] {
        [String(localized: "usage.history.date", defaultValue: "Date"),
         String(localized: "usage.history.who", defaultValue: "Changed by"),
         String(localized: "usage.history.old", defaultValue: "Old limit"),
         String(localized: "usage.history.new", defaultValue: "New limit")]
    }
}

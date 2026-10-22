//
//  AdminAuditLogDisplay.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come una modifica si mostra: la riga della lista, il gruppo di giorno e il dettaglio. Sono testi già pronti,
//  la vista li disegna soltanto.
//

import Foundation

/// Il colore di un'azione: creare, togliere (elimina, archivia), cambiare, altro.
nonisolated enum AdminAuditLogTone: Sendable, Hashable {
    case added, changed, removed, neutral
}

/// Una riga della lista: "Marco ha aggiornato Ordine di lavoro …", con l'ora relativa.
nonisolated struct AdminAuditLogRowItem: Identifiable, Hashable, Sendable {
    let id: String
    let icon: String
    let tone: AdminAuditLogTone
    let sentence: String
    let time: String?
}

/// Un giorno della lista: "Oggi", "Ieri" o la data.
nonisolated struct AdminAuditLogDaySection: Identifiable, Hashable, Sendable {
    let day: Date?
    let title: String
    var rows: [AdminAuditLogRowItem]

    var id: String { day.map { String($0.timeIntervalSince1970) } ?? "no-date" }
}

/// Una coppia etichetta-valore del dettaglio.
nonisolated struct AdminAuditLogField: Identifiable, Hashable, Sendable {
    let label: String
    let value: String

    var id: String { label }
}

/// Un campo cambiato nel dettaglio: "prima → dopo". Un valore mancante si mostra come trattino.
nonisolated struct AdminAuditLogChangeItem: Identifiable, Hashable, Sendable {
    let field: String
    let old: String
    let new: String

    var id: String { field }
}

/// Il dettaglio di una modifica: tutti i campi che il server dà, e le modifiche ai campi.
nonisolated struct AdminAuditLogDetail: Hashable, Sendable {
    let title: String
    let icon: String
    let tone: AdminAuditLogTone
    let fields: [AdminAuditLogField]
    let changes: [AdminAuditLogChangeItem]
    /// `changes` non strutturato, così com'è.
    let note: String?
}

//
//  AdminWorkOrderDetailItems.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I pezzi del dettaglio già pronti da mostrare: gruppi di campi (etichetta e valore) e righe dei passi
//  con il loro resoconto.
//

import Foundation

/// Una riga "etichetta — valore" del dettaglio.
nonisolated struct AdminWorkOrderField: Identifiable, Hashable, Sendable {
    let label: String
    let value: String
    /// In rosso (scadenza superata).
    var isAlert = false

    var id: String { label }
}

/// Una scheda del dettaglio: titolo, icona e i campi che hanno un valore.
nonisolated struct AdminWorkOrderFieldGroup: Identifiable, Hashable, Sendable {
    let title: String
    let icon: String
    let fields: [AdminWorkOrderField]

    var id: String { title }
}

/// Un testo lungo (descrizione, note, note di chiusura).
nonisolated struct AdminWorkOrderTextBlock: Identifiable, Hashable, Sendable {
    let title: String
    let icon: String
    let text: String

    var id: String { title }
}

/// Un passo della procedura con il risultato, chi l'ha registrato e quando.
nonisolated struct AdminStepRowItem: Identifiable, Hashable, Sendable {
    let id: String
    let number: Int
    let text: String
    /// `nil`: ancora da fare.
    let status: AdminStepStatus?
    let note: String?
    /// "Mario Rossi · 22 ott, 10:30 · Phone".
    let byline: String?
    let photoCount: Int
}

//
//  AdminKnowledgeGraphTile.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una casella della panoramica: quante entità di un tipo ci sono, oppure perché non si vedono
//  (lista ancora in arrivo, ruolo senza permesso, errore).
//

import Foundation

nonisolated struct AdminKnowledgeGraphTile: Sendable, Hashable, Identifiable {
    enum State: Sendable, Hashable {
        case loading
        case count(Int)
        case unavailable(String)
    }

    let kind: AdminKnowledgeGraphKind
    let state: State

    var id: AdminKnowledgeGraphKind { kind }

    var isAvailable: Bool {
        if case .count = state { true } else { false }
    }
}

/// Un testo lungo del dettaglio: descrizione, cause tipiche, passi di risoluzione, attività.
nonisolated struct AdminKnowledgeGraphTextBlock: Sendable, Hashable, Identifiable {
    let title: String
    let systemImage: String
    /// Un elemento = paragrafo; con più elementi diventa un elenco.
    let lines: [String]

    var id: String { title }
}

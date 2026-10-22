//
//  AdminKnowledgeGraphNode.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un nodo del grafo come lo mostra l'app: il riferimento (tipo + chiave) per navigare e i testi della
//  riga. Le rotte della navigazione: lista di un tipo, entità, tutte le relazioni di un tipo.
//

import Foundation

/// Tipo e chiave normalizzata (tag, codice, id…): identifica un'entità fra un caricamento e l'altro.
nonisolated struct AdminKnowledgeGraphRef: Sendable, Hashable {
    let kind: AdminKnowledgeGraphKind
    let key: String
}

nonisolated struct AdminKnowledgeGraphNode: Sendable, Hashable, Identifiable {
    let ref: AdminKnowledgeGraphRef
    let title: String
    var subtitle: String?
    /// Terza riga discreta (zona, scadenza, scorta…).
    var detail: String?
    /// Stato già leggibile ("In progress", "Approved").
    var status: String?
    /// I testi in cui cerca la ricerca globale.
    var searchable: [String] = []

    var id: AdminKnowledgeGraphRef { ref }
    var kind: AdminKnowledgeGraphKind { ref.kind }
}

/// I nodi di un tipo collegati a un'entità (o trovati dalla ricerca).
nonisolated struct AdminKnowledgeGraphRelationGroup: Sendable, Hashable, Identifiable {
    let kind: AdminKnowledgeGraphKind
    let nodes: [AdminKnowledgeGraphNode]

    var id: AdminKnowledgeGraphKind { kind }
}

/// Un nodo con il numero dei suoi collegamenti (i nodi centrali della panoramica).
nonisolated struct AdminKnowledgeGraphNodeLinks: Sendable, Hashable, Identifiable {
    let node: AdminKnowledgeGraphNode
    let links: Int

    var id: AdminKnowledgeGraphRef { node.ref }
}

nonisolated enum AdminKnowledgeGraphRoute: Sendable, Hashable {
    case kind(AdminKnowledgeGraphKind)
    case entity(AdminKnowledgeGraphRef)
    case related(AdminKnowledgeGraphRef, AdminKnowledgeGraphKind)
}

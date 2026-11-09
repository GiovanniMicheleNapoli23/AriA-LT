//
//  AdminMarketplaceShelf.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  I pezzi che la lista del Marketplace mostra già pronti: lo scaffale (titolo, nota e schede), la scheda
//  del selettore di tipo con il suo conteggio, un'opzione di faccetta e un filtro attivo da togliere.
//

import Foundation

/// Un gruppo della lista: un tipo (a "Tutti") o un'area (con un tipo scelto).
nonisolated struct AdminMarketplaceShelf: Identifiable, Sendable {
    let id: String
    let title: String
    let blurb: String
    let items: [AdminMarketplaceItem]
    /// Connettori del server che il catalogo non conosce (personalizzati, orfani): restano visibili come prima.
    var extraConnectors: [AdminConnector] = []
}

/// Una scheda del selettore: "Tutti 71", "Skill 14". `kind` nil è "Tutti".
nonisolated struct AdminMarketplaceKindChip: Identifiable, Sendable {
    let kind: AdminMarketplaceKind?
    let title: String
    let count: Int
    let isSelected: Bool

    var id: String { kind?.rawValue ?? "all" }
}

/// Un valore di una faccetta dei full set, col numero di full set che resterebbero: "Krones (2)".
nonisolated struct AdminMarketplaceFacetOption: Identifiable, Sendable {
    let value: String
    let count: Int

    var id: String { value }
    var label: String { "\(value) (\(count))" }
}

/// Un filtro attivo, come chip da togliere sotto il selettore.
nonisolated struct AdminMarketplaceActiveFilter: Identifiable, Sendable {
    enum Kind: Sendable { case area, ownership, machineType, manufacturer, industry }

    let kind: Kind
    let title: String

    var id: Kind { kind }
}

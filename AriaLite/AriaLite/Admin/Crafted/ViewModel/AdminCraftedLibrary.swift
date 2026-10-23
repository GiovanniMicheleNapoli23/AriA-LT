//
//  AdminCraftedLibrary.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Quello che la lista di Crafted mostra, già pronto per la vista: i chip delle categorie con i conteggi,
//  i gruppi per mese, l'eventuale stato vuoto e come si presenta ogni riga. Calcolato dal VM, la vista non decide niente.
//

import SwiftUI

/// Come si ordina la lista (SORTS della web).
nonisolated enum AdminCraftedSort: String, CaseIterable, Identifiable, Sendable {
    case recent, name

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recent: String(localized: "Most recent")
        case .name: String(localized: "Name")
        }
    }
}

/// Un chip del filtro: una categoria presente e quante righe ha con la ricerca di adesso.
struct AdminCraftedCategoryChip: Identifiable, Hashable {
    let category: AdminCraftedCategory
    let count: Int

    var id: String { category.id }
}

/// Le righe di un mese; `label` è nil quando l'ordine è per nome (un mese spezzerebbe l'elenco).
struct AdminCraftedGroup: Identifiable {
    let id: String
    let label: String?
    var items: [AdminCraftedItem]
}

/// Perché la lista non ha righe da mostrare.
enum AdminCraftedEmptyState: Equatable {
    case loading
    /// Niente corrisponde alla ricerca (e alla categoria, se scelta).
    case noMatch(query: String, category: String?)
    /// session-reviews è solo di owner e admin.
    case restricted
    case failed(String)
    /// Ancora niente di creato.
    case empty
}

/// Un avviso sopra la lista quando metà dei dati manca: i rapporti non si leggono, ma gli artifact sì.
enum AdminCraftedReviewsNote: Equatable {
    case restricted
    case failed(String)
}

/// La lista com'è adesso, calcolata una volta per ogni disegno della vista.
struct AdminCraftedLibrary {
    var chips: [AdminCraftedCategoryChip] = []
    /// Righe che corrispondono alla ricerca, di qualsiasi categoria (il numero di "Tutti").
    var searchedCount = 0
    /// La categoria che filtra davvero: una svuotata (l'ultimo "non pronto" è tornato) ricade su tutto.
    var selectedCategory: AdminCraftedCategory?
    var groups: [AdminCraftedGroup] = []
    var visibleCount = 0
    var emptyState: AdminCraftedEmptyState?
    var note: AdminCraftedReviewsNote?
}

/// Come si presenta una riga della lista.
struct AdminCraftedRowInfo {
    var systemImage: String
    var isGenerating = false
    var dateText: String
    /// Tipo, stato o verdetto, dopo la data.
    var detail: String?
    var detailTint: Color?
    /// Il pallino del verdetto prima del testo (solo i rapporti).
    var showsVerdictDot = false
    var isError = false
    /// "Modificato · v3": non è più solo quello che ha fatto Aria.
    var edited: String?
}

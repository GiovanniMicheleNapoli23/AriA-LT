//
//  AdminCategoriesViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Categories, come la pagina /categories della web. Vive in AppViewModel: i dati restano fra un
//  cambio di sezione e l'altro. L'elenco è di tutta l'azienda: tipo e stabilimento filtrano sul telefono, così
//  le voci dei filtri sono quelle presenti davvero. Le azioni di modifica sono in +Actions.swift.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminCategoriesViewModel {
    let backend: AriaBackend

    /// Cosa mostrare al posto della lista.
    enum Placeholder: Equatable {
        case loading
        case failed(AdminCategoriesFailure)
        case empty
        case noMatches
    }

    // MARK: - State

    var categories: [AdminCategory] = []
    /// Azienda per cui l'elenco è stato scaricato.
    var loadedCompanyId: String?
    private(set) var isLoading = false
    private(set) var failure: AdminCategoriesFailure?
    private(set) var lastUpdated: Date?

    var query = ""
    /// Tipo scelto nel filtro (`nil` = tutti).
    var entityFilter: String?
    /// Stabilimento scelto nel filtro (`nil` = tutti gli stabilimenti).
    var plantFilter: String?

    /// Il modulo aperto (nuova o modifica), nello sheet.
    var form: AdminCategoryFormViewModel?
    /// La categoria da eliminare: chiede conferma prima.
    var pendingDelete: AdminCategory?
    var isDeleting = false
    /// Errore dell'eliminazione (alert).
    var deleteError: String?

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// All'uscita dall'account: niente dati dell'azienda precedente.
    func reset() {
        categories = []
        loadedCompanyId = nil
        isLoading = false
        failure = nil
        lastUpdated = nil
        query = ""
        entityFilter = nil
        plantFilter = nil
        form = nil
        pendingDelete = nil
        isDeleting = false
        deleteError = nil
    }

    // MARK: - Caricamento

    /// Cambia quando va riscaricato l'elenco: l'azienda.
    var loadKey: String { backend.activeCompanyId ?? "-" }

    var hasLoaded: Bool { loadedCompanyId == backend.activeCompanyId }

    func loadIfNeeded() async {
        if !hasLoaded { await refresh() }
    }

    func refresh() async {
        let companyId = backend.activeCompanyId
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await AdminCategoriesAPI(api: backend.api).list()
            // Nel frattempo è cambiata l'azienda: questo elenco non è più quello giusto.
            guard companyId == backend.activeCompanyId else { return }
            categories = fresh
            loadedCompanyId = companyId
            failure = nil
            lastUpdated = .now
        } catch {
            if let failure = AdminCategoriesFailure.from(error, action: .read, backend: backend) {
                self.failure = failure
            }
        }
    }

    // MARK: - Filtri

    var visibleCategories: [AdminCategory] {
        categories.filter(matches).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func matches(_ category: AdminCategory) -> Bool {
        if let entityFilter, category.entityType != entityFilter { return false }
        if let plantFilter, category.plantId != plantFilter { return false }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty || category.name.localizedStandardContains(q)
    }

    /// I tipi presenti nell'elenco, in ordine alfabetico.
    var entityTypes: [String] {
        Array(Set(categories.map(\.entityType).filter { !$0.isEmpty }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Gli stabilimenti dell'azienda, per il filtro e il modulo.
    var plants: [AriaPlant] { backend.plants }

    var hasActiveFilters: Bool { entityFilter != nil || plantFilter != nil }

    /// Il nome dello stabilimento di una categoria, se lo conosciamo.
    func plantName(for category: AdminCategory) -> String? {
        guard let plantId = category.plantId else { return nil }
        return backend.plants.first { $0.id == plantId }?.name
    }

    func clearFilters() {
        entityFilter = nil
        plantFilter = nil
    }

    var placeholder: Placeholder? {
        if !hasLoaded {
            if let failure { return .failed(failure) }
            return .loading
        }
        if categories.isEmpty { return .empty }
        return visibleCategories.isEmpty ? .noMatches : nil
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito.
    var refreshFailed: Bool { hasLoaded && failure != nil }

    /// Il messaggio di conferma dell'eliminazione.
    var deleteMessage: String {
        guard let pendingDelete else { return "" }
        return String(localized: "“\(pendingDelete.name)” will be deleted. This can't be undone.")
    }

    var isShowingDeleteConfirmation: Bool {
        get { pendingDelete != nil }
        set { if !newValue { pendingDelete = nil } }
    }

    var isShowingDeleteError: Bool {
        get { deleteError != nil }
        set { if !newValue { deleteError = nil } }
    }
}

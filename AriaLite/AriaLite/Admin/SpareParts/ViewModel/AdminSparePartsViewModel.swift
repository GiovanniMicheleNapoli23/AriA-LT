//
//  AdminSparePartsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I ricambi, come la pagina /spare-parts della web.
//  Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//  Due elenchi dello stabilimento attivo: tutti (GET /v1/spare-parts) e scorta bassa (…/low-stock).
//  Stato, categoria e ricerca filtrano sul telefono, senza richiamare il server.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminSparePartsViewModel {
    let backend: AriaBackend
    let vendors: AdminSparePartVendorsViewModel

    /// Cosa mostrare al posto della lista.
    enum Placeholder: Equatable {
        case loading
        case failed(AdminSparePartsFailure)
        case noPlant
        case empty
        case noLowStock
        case noResults(String)
        case noMatches
    }

    /// Lo stabilimento per cui un elenco è stato scaricato (`nil` = nessuno stabilimento scelto).
    private struct Scope: Equatable { let plantId: String? }

    // MARK: - State

    private(set) var allParts: [AdminSparePart] = []
    private(set) var lowStockParts: [AdminSparePart] = []
    private var allScope: Scope?
    private var lowStockScope: Scope?
    private(set) var isLoading = false
    private(set) var failure: AdminSparePartsFailure?
    private(set) var lastUpdated: Date?

    var query = ""
    var showLowStockOnly = false
    var statusFilter: AdminSparePartStatus?
    var categoryFilter: AdminSparePartCategory?
    /// Il modulo di creazione aperto (sheet).
    var newPartForm: AdminSparePartFormViewModel?

    init(backend: AriaBackend) {
        self.backend = backend
        vendors = AdminSparePartVendorsViewModel(backend: backend)
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        allParts = []
        lowStockParts = []
        allScope = nil
        lowStockScope = nil
        failure = nil
        lastUpdated = nil
        query = ""
        showLowStockOnly = false
        statusFilter = nil
        categoryFilter = nil
        newPartForm = nil
        vendors.reset()
    }

    // MARK: - Caricamento

    private var currentScope: Scope { Scope(plantId: backend.activePlantId) }

    /// Cambia quando va riscaricato qualcosa: stabilimento o elenco (tutti / scorta bassa).
    var loadKey: String { "\(backend.activePlantId ?? "-")|\(showLowStockOnly)" }

    /// L'elenco mostrato è già dello stabilimento attivo.
    var hasLoaded: Bool { (showLowStockOnly ? lowStockScope : allScope) == currentScope }

    func loadIfNeeded() async {
        if !hasLoaded { await refresh() }
        await vendors.loadIfNeeded()
    }

    func refresh() async {
        let scope = currentScope
        let lowStock = showLowStockOnly
        let api = AdminSparePartsAPI(api: backend.api)
        isLoading = true
        defer { isLoading = false }
        do {
            if lowStock {
                lowStockParts = try await api.lowStock(plantId: scope.plantId)
                lowStockScope = scope
            } else {
                allParts = try await api.list(plantId: scope.plantId)
                allScope = scope
            }
            failure = nil
            lastUpdated = .now
        } catch {
            if let failure = AdminSparePartsFailure.from(error, action: .read, backend: backend) { self.failure = failure }
        }
    }

    // MARK: - Filtri

    private var source: [AdminSparePart] { showLowStockOnly ? lowStockParts : allParts }

    var visibleParts: [AdminSparePart] { source.filter(matches) }

    private func matches(_ part: AdminSparePart) -> Bool {
        if let statusFilter, part.status != statusFilter { return false }
        if let categoryFilter, part.category != categoryFilter { return false }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        return [part.code, part.name, part.partNumber, part.manufacturer, part.barcode].contains {
            $0?.localizedStandardContains(q) == true
        }
    }

    /// Gli stati presenti nell'elenco, più quello scelto (resta visibile anche se non c'è più).
    var statusOptions: [AdminSparePartStatus] {
        let present = Set(source.compactMap(\.status)).union(statusFilter.map { [$0] } ?? [])
        return AdminSparePartStatus.allCases.filter(present.contains)
    }

    var categoryOptions: [AdminSparePartCategory] {
        let present = Set(source.compactMap(\.category)).union(categoryFilter.map { [$0] } ?? [])
        return AdminSparePartCategory.allCases.filter(present.contains)
    }

    /// Quanti ricambi sono sotto scorta nell'elenco completo (`nil` finché non c'è).
    var lowStockCount: Int? {
        guard allScope == currentScope else { return nil }
        return allParts.count(where: \.isLowStock)
    }

    var hasActiveFilters: Bool { showLowStockOnly || statusFilter != nil || categoryFilter != nil }

    /// L'errore era dell'altro elenco: non vale per questo.
    func toggleLowStock() {
        showLowStockOnly.toggle()
        failure = nil
    }

    func selectStatus(_ status: AdminSparePartStatus?) { statusFilter = status }

    func selectCategory(_ category: AdminSparePartCategory?) { categoryFilter = category }

    func clearFilters() {
        if showLowStockOnly { toggleLowStock() }
        statusFilter = nil
        categoryFilter = nil
    }

    var placeholder: Placeholder? {
        if !hasLoaded {
            if let failure { return .failed(failure) }
            return .loading
        }
        if backend.activePlantId == nil && source.isEmpty { return .noPlant }
        if source.isEmpty { return showLowStockOnly ? .noLowStock : .empty }
        guard visibleParts.isEmpty else { return nil }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty ? .noMatches : .noResults(q)
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito.
    var refreshFailed: Bool { hasLoaded && failure != nil }

    // MARK: - Modifiche

    func startCreating() {
        newPartForm = AdminSparePartFormViewModel(mode: .create, owner: self)
    }

    /// Un ricambio creato: in cima all'elenco dello stabilimento (e fra quelli sotto scorta, se lo è).
    func didCreate(_ part: AdminSparePart) {
        if part.plantId == nil || part.plantId == backend.activePlantId {
            allParts.insert(part, at: 0)
            if part.isLowStock, lowStockScope != nil { lowStockParts.insert(part, at: 0) }
        }
    }

    /// Un ricambio modificato (modulo o quantità): si aggiorna dov'è; entra o esce dalla scorta bassa.
    func didSave(_ part: AdminSparePart) {
        if let index = allParts.firstIndex(where: { $0.id == part.id }) { allParts[index] = part }
        if let index = lowStockParts.firstIndex(where: { $0.id == part.id }) {
            if part.isLowStock { lowStockParts[index] = part } else { lowStockParts.remove(at: index) }
        } else if part.isLowStock, lowStockScope != nil, allParts.contains(where: { $0.id == part.id }) {
            lowStockParts.append(part)
        }
    }
}

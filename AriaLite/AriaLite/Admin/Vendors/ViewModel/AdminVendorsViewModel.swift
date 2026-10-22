//
//  AdminVendorsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Vendors, come la pagina /vendors della web.
//  Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//  L'elenco è dello stabilimento attivo (GET /v1/vendors?plant_id=); tipo e ricerca filtrano sul telefono,
//  senza richiamare il server, così le voci del filtro restano quelle di tutto l'elenco.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminVendorsViewModel {
    let backend: AriaBackend

    /// Cosa mostrare al posto della lista.
    enum Placeholder: Equatable {
        case loading
        case failed(AdminVendorsFailure)
        case empty
        case noResults(String)
        case noMatches
    }

    /// Azienda e stabilimento per cui l'elenco è stato scaricato (`nil` = nessuno stabilimento scelto).
    private struct Scope: Equatable {
        let companyId: String?
        let plantId: String?
    }

    // MARK: - State

    private(set) var vendors: [AdminVendor] = []
    private var loadedScope: Scope?
    private(set) var isLoading = false
    private(set) var failure: AdminVendorsFailure?
    private(set) var lastUpdated: Date?

    var query = ""
    /// La chiave del tipo scelto (vedi `AdminVendorType.key`).
    var typeFilter: String?
    /// Il modulo di creazione aperto (sheet).
    var newVendorForm: AdminVendorFormViewModel?

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        vendors = []
        loadedScope = nil
        isLoading = false
        failure = nil
        lastUpdated = nil
        query = ""
        typeFilter = nil
        newVendorForm = nil
    }

    // MARK: - Caricamento

    private var currentScope: Scope { Scope(companyId: backend.activeCompanyId, plantId: backend.activePlantId) }

    /// Cambia quando va riscaricato l'elenco: azienda o stabilimento.
    var loadKey: String { "\(backend.activeCompanyId ?? "-")|\(backend.activePlantId ?? "-")" }

    /// L'elenco mostrato è già dello stabilimento attivo.
    var hasLoaded: Bool { loadedScope == currentScope }

    func loadIfNeeded() async {
        if !hasLoaded { await refresh() }
    }

    func refresh() async {
        let scope = currentScope
        let api = AdminVendorsAPI(api: backend.api)
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await api.list(plantId: scope.plantId)
            // Nel frattempo è cambiato lo stabilimento: questo elenco non è più quello giusto.
            guard scope == currentScope else { return }
            vendors = fresh
            loadedScope = scope
            failure = nil
            lastUpdated = .now
        } catch {
            if let failure = AdminVendorsFailure.from(error, action: .read, backend: backend) { self.failure = failure }
        }
    }

    // MARK: - Filtri

    var visibleVendors: [AdminVendor] {
        vendors.filter(matches).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func matches(_ vendor: AdminVendor) -> Bool {
        if let typeFilter, vendor.typeKey != typeFilter { return false }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        return [vendor.name, vendor.companyName, vendor.city, vendor.email].contains {
            $0?.localizedStandardContains(q) == true
        }
    }

    /// I tipi presenti nell'elenco, più quello scelto (resta visibile anche se non c'è più).
    var typeOptions: [AdminVendorTypeOption] {
        var found: [String: (label: String, count: Int)] = [:]
        for vendor in vendors {
            guard let key = vendor.typeKey, let label = vendor.typeLabel else { continue }
            found[key] = (found[key]?.label ?? label, (found[key]?.count ?? 0) + 1)
        }
        if let typeFilter, found[typeFilter] == nil { found[typeFilter] = (AdminVendorType.label(typeFilter), 0) }
        return found.map { AdminVendorTypeOption(key: $0.key, label: $0.value.label, count: $0.value.count) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    /// Un solo tipo non è un filtro: la fila compare da due in su (o se un filtro è già attivo).
    var showsTypeFilter: Bool { typeOptions.count > 1 || typeFilter != nil }

    /// I tipi già usati come li ha scritti l'utente, per suggerirli nel modulo.
    var typeSuggestions: [String] {
        var seen = Set<String>()
        return vendors.compactMap(\.vendorType)
            .filter { seen.insert(AdminVendorType.key($0)).inserted }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var hasActiveFilters: Bool { typeFilter != nil }

    func selectType(_ key: String?) { typeFilter = key }

    func clearFilters() { typeFilter = nil }

    var placeholder: Placeholder? {
        if !hasLoaded {
            if let failure { return .failed(failure) }
            return .loading
        }
        if vendors.isEmpty { return .empty }
        guard visibleVendors.isEmpty else { return nil }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty ? .noMatches : .noResults(q)
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito.
    var refreshFailed: Bool { hasLoaded && failure != nil }

    // MARK: - Modifiche

    func startCreating() {
        newVendorForm = AdminVendorFormViewModel(mode: .create, owner: self)
    }

    /// Un fornitore creato: entra nell'elenco se è dello stabilimento attivo (o di nessuno).
    func didCreate(_ vendor: AdminVendor) {
        guard vendor.plantId == nil || vendor.plantId == backend.activePlantId else { return }
        vendors.removeAll { $0.id == vendor.id }
        vendors.append(vendor)
    }

    /// Un fornitore modificato o riletto: si aggiorna dov'è.
    func didSave(_ vendor: AdminVendor) {
        if let index = vendors.firstIndex(where: { $0.id == vendor.id }) { vendors[index] = vendor }
    }

    func didDelete(id: String) {
        vendors.removeAll { $0.id == id }
        // L'ultimo del suo tipo se n'è andato: il filtro non ha più niente da mostrare.
        if let typeFilter, !vendors.contains(where: { $0.typeKey == typeFilter }) { self.typeFilter = nil }
    }
}

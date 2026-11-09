//
//  AdminPurchaseOrdersViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Purchase Orders, come la pagina /purchase-orders della web.
//  Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//  L'elenco è dello stabilimento attivo, con stato e fornitore filtrati dal server (status=, vendor_id=);
//  la ricerca filtra sul telefono. Qui stato, caricamento e modifiche; testi e riepilogo in +Display.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminPurchaseOrdersViewModel {
    let backend: AriaBackend
    let lookups: AdminPurchaseOrderLookups

    /// Cosa mostrare al posto della lista.
    enum Placeholder: Equatable {
        case loading
        case failed(AdminPurchaseOrdersFailure)
        case noPlant
        case empty
        case noResults(String)
        case noMatches
    }

    /// Per cosa un elenco è stato scaricato: stabilimento, stato e fornitore (`nil` = nessun filtro).
    struct Scope: Equatable {
        let plantId: String?
        let status: String?
        let vendorId: String?
    }

    // MARK: - State

    private(set) var orders: [AdminPurchaseOrder] = []
    private(set) var loadedScope: Scope?
    private(set) var isLoading = false
    private(set) var failure: AdminPurchaseOrdersFailure?
    private(set) var failureScope: Scope?
    private(set) var lastUpdated: Date?

    var query = ""
    private(set) var statusFilter: AdminPurchaseOrderStatus?
    private(set) var vendorFilter: String?
    /// Il modulo aperto (sheet), per creare un ordine.
    var form: AdminPurchaseOrderFormViewModel?
    /// Il percorso di navigazione: chiude i dettagli che escono dal percorso.
    var path: [AdminPurchaseOrderRoute] = [] {
        didSet { pruneDetailViewModels() }
    }
    /// I dettagli aperti, per id: lo stato di un dettaglio non si perde se la vista si ridisegna.
    @ObservationIgnored private var detailViewModels: [String: AdminPurchaseOrderDetailViewModel] = [:]

    init(backend: AriaBackend) {
        self.backend = backend
        lookups = AdminPurchaseOrderLookups(backend: backend)
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        orders = []
        loadedScope = nil
        failure = nil
        failureScope = nil
        lastUpdated = nil
        query = ""
        statusFilter = nil
        vendorFilter = nil
        form = nil
        path = []
        detailViewModels = [:]
        lookups.reset()
    }

    // MARK: - Caricamento

    var currentScope: Scope {
        Scope(plantId: backend.activePlantId, status: statusFilter?.rawFilterValue, vendorId: vendorFilter)
    }

    /// Cambia quando va riscaricato l'elenco: stabilimento, stato o fornitore.
    var loadKey: String {
        "\(backend.activePlantId ?? "-")|\(statusFilter?.rawFilterValue ?? "-")|\(vendorFilter ?? "-")"
    }

    /// L'elenco mostrato è quello dei filtri attuali.
    var hasLoaded: Bool { loadedScope == currentScope }

    func loadIfNeeded() async {
        async let vendors: Void = lookups.loadIfNeeded()
        if !hasLoaded { await refreshOrders() }
        await vendors
    }

    /// Aggiorna elenco e fornitori insieme (tirare per aggiornare).
    func refresh() async {
        async let vendors: Void = lookups.refresh()
        await refreshOrders()
        await vendors
    }

    private func refreshOrders() async {
        let scope = currentScope
        let api = AdminPurchaseOrdersAPI(api: backend.api)
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await api.list(plantId: scope.plantId, status: scope.status, vendorId: scope.vendorId)
            // Filtri cambiati mentre si scaricava: questo elenco non è più quello giusto.
            guard scope == currentScope else { return }
            orders = loaded
            loadedScope = scope
            failure = nil
            failureScope = nil
            lastUpdated = .now
        } catch {
            if let failure = AdminPurchaseOrdersFailure.from(error, action: .read, backend: backend) {
                self.failure = failure
                failureScope = scope
            }
        }
    }

    /// L'errore dell'ultimo caricamento, se è dei filtri attuali.
    var currentFailure: AdminPurchaseOrdersFailure? { failureScope == currentScope ? failure : nil }

    // MARK: - Filtri

    var hasActiveFilters: Bool { statusFilter != nil || vendorFilter != nil }

    func selectStatus(_ status: AdminPurchaseOrderStatus?) { statusFilter = status }

    func selectVendor(_ vendorId: String?) { vendorFilter = vendorId }

    func clearFilters() {
        statusFilter = nil
        vendorFilter = nil
    }

    /// L'ordine rientra nei filtri e nello stabilimento attuali (come li applicherebbe il server).
    private func matchesScope(_ order: AdminPurchaseOrder) -> Bool {
        if let plant = backend.activePlantId, let orderPlant = order.plantId, orderPlant != plant { return false }
        if let statusFilter, order.statusKind != statusFilter { return false }
        if let vendorFilter, order.vendorId != vendorFilter { return false }
        return true
    }

    // MARK: - Creazione e modifiche

    /// Si può creare un ordine: serve uno stabilimento.
    var canCreate: Bool { backend.activePlantId != nil || !backend.plants.isEmpty }

    func startCreating() {
        guard canCreate else { return }
        // I fornitori potrebbero essere cambiati dalla sezione Fornitori: il selettore parte aggiornato.
        Task { await lookups.refreshIfStale() }
        form = AdminPurchaseOrderFormViewModel(mode: .create, backend: backend, lookups: lookups) { [weak self] in
            self?.didCreate($0)
        }
    }

    /// Un ordine creato: in cima all'elenco se rientra nei filtri, poi se ne apre il dettaglio.
    func didCreate(_ order: AdminPurchaseOrder) {
        if hasLoaded, matchesScope(order), !orders.contains(where: { $0.id == order.id }) {
            orders.insert(order, at: 0)
        }
        _ = makeDetailViewModel(for: order)
        path.append(.order(order.id))
    }

    /// Un ordine modificato dal dettaglio: si aggiorna la riga; se non rientra più nei filtri esce dall'elenco.
    func didChange(_ order: AdminPurchaseOrder) {
        guard let index = orders.firstIndex(where: { $0.id == order.id }) else { return }
        if matchesScope(order) { orders[index] = order } else { orders.remove(at: index) }
    }

    /// Un ordine eliminato: via dall'elenco e dal percorso.
    func didDelete(_ id: String) {
        orders.removeAll { $0.id == id }
        detailViewModels[id] = nil
        path.removeAll { $0.id == id }
    }

    // MARK: - Dettaglio

    /// Il dettaglio di un ordine; lo stesso finché resta nel percorso.
    func makeDetailViewModel(for order: AdminPurchaseOrder) -> AdminPurchaseOrderDetailViewModel {
        if let existing = detailViewModels[order.id] { return existing }
        let detail = AdminPurchaseOrderDetailViewModel(
            backend: backend, order: order, lookups: lookups,
            onChanged: { [weak self] in self?.didChange($0) },
            onDeleted: { [weak self] in self?.didDelete($0) })
        detailViewModels[order.id] = detail
        return detail
    }

    /// Il dettaglio per id: quello già aperto, o uno nuovo se l'ordine è in elenco; `nil` se non c'è più.
    func detailViewModel(forId id: String) -> AdminPurchaseOrderDetailViewModel? {
        if let existing = detailViewModels[id] { return existing }
        guard let order = orders.first(where: { $0.id == id }) else { return nil }
        return makeDetailViewModel(for: order)
    }

    private func pruneDetailViewModels() {
        let open = Set(path.map(\.id))
        detailViewModels = detailViewModels.filter { open.contains($0.key) }
    }
}

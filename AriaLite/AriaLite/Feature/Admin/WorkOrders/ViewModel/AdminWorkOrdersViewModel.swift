//
//  AdminWorkOrdersViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli ordini di lavoro dell'azienda, come la pagina /work-orders della web: lista, dettaglio, creazione e modifica.
//  Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//  La lista è dello stabilimento attivo (`plant_id`), si filtra per gruppo di stato e priorità sul server e si
//  cerca per titolo, tag e zona sulle pagine già scaricate. Le pagine arrivano a 50 alla volta, scorrendo.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkOrdersViewModel {
    let backend: AriaBackend
    /// Persone, squadre e asset: nomi per la lista, scelte per il form.
    let directory: AdminWorkOrderDirectory

    private(set) var orders: [AdminWorkOrder] = []
    private(set) var statusGroup: AdminWorkOrderStatusGroup = .open
    private(set) var priority: AdminWorkOrderPriority?
    var searchText = ""

    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var canLoadMore = false
    /// Errore dell'ultimo caricamento (o del caricamento di altre pagine).
    private(set) var errorMessage: String?
    /// Il ruolo non può leggere gli ordini: niente "riprova", si spiega.
    private(set) var isForbidden = false

    /// Il form di creazione aperto (sheet).
    var createForm: AdminWorkOrderFormViewModel?

    static let pageSize = 50

    /// Ogni nuovo caricamento da capo invalida le risposte dei precedenti ancora in volo.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    /// Lo stabilimento della lista mostrata: se cambia, si ricarica.
    @ObservationIgnored private var loadedPlantId: String?

    init(backend: AriaBackend) {
        self.backend = backend
        directory = AdminWorkOrderDirectory(backend: backend)
    }

    private var api: AdminWorkOrdersAPI { AdminWorkOrdersAPI(api: backend.api) }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        loadTask?.cancel()
        generation += 1
        orders = []
        statusGroup = .open
        priority = nil
        searchText = ""
        hasLoaded = false
        isLoading = false
        isLoadingMore = false
        canLoadMore = false
        errorMessage = nil
        isForbidden = false
        createForm = nil
        loadedPlantId = nil
        directory.reset()
    }

    // MARK: Righe

    var rows: [AdminWorkOrderRowItem] { visibleOrders.map(row) }

    /// Gli ordini scaricati che corrispondono alla ricerca (titolo, tag dell'asset, zona).
    private var visibleOrders: [AdminWorkOrder] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return orders }
        return orders.filter { [$0.title, $0.assetTag, $0.zone].contains { $0?.localizedStandardContains(query) == true } }
    }

    private func row(_ order: AdminWorkOrder) -> AdminWorkOrderRowItem {
        let steps = order.stepProgress.flatMap { $0.total > 0 ? $0 : nil }
        return AdminWorkOrderRowItem(
            order: order,
            status: order.status,
            priority: order.priority == .unknown ? nil : order.priority,
            place: AdminWorkOrderFormat.joined([order.assetTag, order.zone]),
            assignee: directory.assigneeName(for: order),
            due: order.isClosed ? nil : order.dueDate.map(AdminWorkOrderFormat.shortDate),
            isOverdue: order.isOverdue(),
            progress: steps?.fraction,
            progressText: steps.map { String(localized: "\($0.reported)/\($0.total) steps") }
        )
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Senza stabilimento la lista sarebbe di tutta l'azienda, e il form non saprebbe dove creare.
    var plantName: String? { backend.activePlantName }

    // MARK: Filtri

    func select(_ group: AdminWorkOrderStatusGroup) {
        guard group != statusGroup else { return }
        statusGroup = group
        reload()
    }

    /// Tocca di nuovo la priorità scelta per toglierla.
    func toggle(_ level: AdminWorkOrderPriority) {
        priority = priority == level ? nil : level
        reload()
    }

    private func query(offset: Int) -> AdminWorkOrderQuery {
        AdminWorkOrderQuery(statusGroup: statusGroup, priority: priority, plantId: backend.activePlantId,
                            limit: Self.pageSize, offset: offset)
    }

    // MARK: Caricamento

    /// All'apertura della sezione e al cambio di stabilimento; altrimenti resta quello che c'è.
    func loadIfNeeded() async {
        guard !hasLoaded || loadedPlantId != backend.activePlantId else { return }
        await load()
    }

    /// Pull-to-refresh: lista da capo e anagrafiche.
    func refresh() async {
        async let directory: Void = directory.load()
        await load()
        await directory
    }

    /// Un filtro è cambiato: la lista riparte da capo, la richiesta precedente si scarta.
    private func reload() {
        loadTask?.cancel()
        loadTask = Task { await load() }
    }

    func load() async {
        generation += 1
        let current = generation
        let plantId = backend.activePlantId
        isLoading = true
        isLoadingMore = false
        errorMessage = nil
        Task { await directory.loadIfNeeded() }
        do {
            let page = try await api.list(query(offset: 0))
            guard current == generation else { return }
            orders = page
            canLoadMore = page.count >= Self.pageSize
            hasLoaded = true
            isForbidden = false
            loadedPlantId = plantId
        } catch {
            guard current == generation else { return }
            fail(error)
        }
        isLoading = false
    }

    /// Scorrendo fino all'ultima riga visibile arriva la pagina dopo.
    func loadMoreIfNeeded(after item: AdminWorkOrderRowItem) {
        guard item.id == visibleOrders.last?.id else { return }
        loadMore()
    }

    func loadMore() {
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        let current = generation
        isLoadingMore = true
        Task {
            do {
                let page = try await api.list(query(offset: orders.count))
                guard current == generation else { return }
                // Fra una pagina e l'altra un ordine può spostarsi: niente doppioni.
                let known = Set(orders.map(\.id))
                orders += page.filter { !known.contains($0.id) }
                canLoadMore = page.count >= Self.pageSize
            } catch {
                guard current == generation else { return }
                fail(error)
            }
            isLoadingMore = false
        }
    }

    private func fail(_ error: any Error) {
        guard let message = AdminWorkOrderFailure.message(for: error, backend: backend) else { return }
        errorMessage = message
        isForbidden = AdminWorkOrderFailure.isForbidden(error)
        canLoadMore = false
    }

    // MARK: Modifiche dal dettaglio e dal form

    /// Un ordine salvato: si aggiorna la sua riga, o si toglie se non è più del gruppo mostrato.
    func didUpdate(_ order: AdminWorkOrder) {
        guard let index = orders.firstIndex(where: { $0.id == order.id }) else { return }
        if belongsToList(order) { orders[index] = order } else { orders.remove(at: index) }
    }

    func didCreate(_ order: AdminWorkOrder) {
        guard belongsToList(order), !orders.contains(where: { $0.id == order.id }) else { return }
        orders.insert(order, at: 0)
    }

    func didDelete(_ id: String) {
        orders.removeAll { $0.id == id }
    }

    /// Lo stesso filtro del server, applicato a un ordine appena salvato.
    private func belongsToList(_ order: AdminWorkOrder) -> Bool {
        if let priority, order.priority != priority { return false }
        if let plant = backend.activePlantId, let orderPlant = order.plantId, orderPlant != plant { return false }
        switch statusGroup {
        case .open: return !order.isClosed
        case .closed: return order.isClosed
        case .all: return true
        }
    }

    // MARK: Schermate figlie

    func startCreating() {
        createForm = AdminWorkOrderFormViewModel(mode: .create, backend: backend, directory: directory) { [weak self] order in
            self?.didCreate(order)
        }
    }

    func detailModel(for order: AdminWorkOrder) -> AdminWorkOrderDetailViewModel {
        AdminWorkOrderDetailViewModel(order: order, list: self)
    }
}

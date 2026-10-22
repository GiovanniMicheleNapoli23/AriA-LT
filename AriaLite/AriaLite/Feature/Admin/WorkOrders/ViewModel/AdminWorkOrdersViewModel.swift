//
//  AdminWorkOrdersViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli ordini di lavoro dell'azienda, come la pagina /work-orders della web: lista, dettaglio, creazione e modifica.
//  Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//  La lista è dello stabilimento attivo (`plant_id`), si filtra sul server per gruppo di stato, stato, priorità,
//  tipo e assegnatario ("Assigned to me" compreso) e si cerca per titolo, tag e zona sulle pagine già scaricate,
//  che si possono anche ordinare. Le pagine arrivano a 50 alla volta, scorrendo. Dalle righe si cambia lo stato
//  (swipe e menu contestuale) con AdminWorkOrderQuickActions.
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
    private(set) var filters = AdminWorkOrderFilters()
    /// Solo sulle pagine scaricate: la rotta non ordina.
    var sort: AdminWorkOrderSort = .newest
    var searchText = ""
    /// Cambio di stato, completamento e assegnazione automatica dalle righe.
    let actions: AdminWorkOrderQuickActions

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
    /// I modelli di ordine, aperti dalla toolbar.
    let templates: AdminWorkOrderTemplatesViewModel
    var isShowingTemplates = false

    static let pageSize = 50

    /// Ogni nuovo caricamento da capo invalida le risposte dei precedenti ancora in volo.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    /// Lo stabilimento della lista mostrata: se cambia, si ricarica.
    @ObservationIgnored private var loadedPlantId: String?

    init(backend: AriaBackend) {
        self.backend = backend
        directory = AdminWorkOrderDirectory(backend: backend)
        templates = AdminWorkOrderTemplatesViewModel(backend: backend)
        actions = AdminWorkOrderQuickActions(backend: backend)
        templates.onOrderCreated = { [weak self] in self?.reload() }
        actions.onUpdated = { [weak self] order in self?.didUpdate(order) }
        actions.onReload = { [weak self] id in await self?.refreshOrder(id) }
    }

    private var api: AdminWorkOrdersAPI { AdminWorkOrdersAPI(api: backend.api) }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        loadTask?.cancel()
        generation += 1
        orders = []
        filters = AdminWorkOrderFilters()
        sort = .newest
        searchText = ""
        actions.reset()
        hasLoaded = false
        isLoading = false
        isLoadingMore = false
        canLoadMore = false
        errorMessage = nil
        isForbidden = false
        createForm = nil
        loadedPlantId = nil
        isShowingTemplates = false
        templates.reset()
        directory.reset()
    }

    // MARK: Righe

    var rows: [AdminWorkOrderRowItem] { visibleOrders.map(row) }

    /// Gli ordini scaricati che corrispondono alla ricerca (titolo, tag dell'asset, zona), nell'ordine scelto.
    private var visibleOrders: [AdminWorkOrder] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = query.isEmpty ? orders
            : orders.filter { [$0.title, $0.assetTag, $0.zone].contains { $0?.localizedStandardContains(query) == true } }
        return sort.sorted(matching)
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
            progressText: steps.map { "\($0.reported)/\($0.total)" },
            isBusy: actions.isBusy(order)
        )
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Senza stabilimento la lista sarebbe di tutta l'azienda, e il form non saprebbe dove creare.
    var plantName: String? { backend.activePlantName }

    // MARK: Filtri

    var statusGroup: AdminWorkOrderStatusGroup { filters.statusGroup }
    var priority: AdminWorkOrderPriority? { filters.priority }

    /// L'id dell'account collegato, per "Assigned to me"; senza, il filtro non si offre.
    var myUserId: String? { backend.mobileAccount?.id }

    /// I filtri cambiano: la lista riparte da capo.
    func apply(_ filters: AdminWorkOrderFilters) {
        guard filters != self.filters else { return }
        self.filters = filters
        reload()
    }

    /// Un gruppo di stato toglie lo stato preciso, che lo renderebbe inutile.
    func select(_ group: AdminWorkOrderStatusGroup) {
        var next = filters
        next.statusGroup = group
        next.status = nil
        apply(next)
    }

    /// Tocca di nuovo la priorità scelta per toglierla.
    func toggle(_ level: AdminWorkOrderPriority) {
        var next = filters
        next.priority = filters.priority == level ? nil : level
        apply(next)
    }

    /// "Mine": gli ordini assegnati all'account collegato, o di nuovo tutti.
    func toggleMine() {
        var next = filters
        next.assignee = filters.assignee == .me ? .anyone : .me
        apply(next)
    }

    func clearFilters() {
        apply(AdminWorkOrderFilters(statusGroup: filters.statusGroup))
    }

    /// Le persone fra cui filtrare, senza l'account collegato (c'è "Assigned to me").
    var assigneeChoices: [AdminWorkOrderUser] {
        directory.activeUsers.filter { $0.id != myUserId }
    }

    /// Il nome sul chip "Filters" quando si filtra per una persona.
    var assigneeFilterName: String? {
        switch filters.assignee {
        case .anyone: nil
        case .me: String(localized: "Me")
        case .user(let id): directory.user(id)?.displayName ?? id
        }
    }

    private func query(offset: Int) -> AdminWorkOrderQuery {
        filters.query(plantId: backend.activePlantId, me: myUserId, limit: Self.pageSize, offset: offset)
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
    func reload() {
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
        if let plant = backend.activePlantId, let orderPlant = order.plantId, orderPlant != plant { return false }
        return filters.matches(order, me: myUserId)
    }

    /// Dopo l'assegnazione automatica: l'ordine si rilegge e la sua riga si aggiorna.
    private func refreshOrder(_ id: String) async {
        do {
            didUpdate(try await api.detail(id))
        } catch {
            if let message = AdminWorkOrderFailure.message(for: error, backend: backend) { errorMessage = message }
        }
    }

    // MARK: Azioni rapide

    func statusChoices(for item: AdminWorkOrderRowItem) -> [AdminWorkOrderStatus] { actions.statusChoices(for: item.order) }
    func leadingSwipe(for item: AdminWorkOrderRowItem) -> AdminWorkOrderStatus? { actions.leadingSwipe(for: item.order) }
    func canComplete(_ item: AdminWorkOrderRowItem) -> Bool { actions.canComplete(item.order) }
    func changeStatus(_ item: AdminWorkOrderRowItem, to status: AdminWorkOrderStatus) { actions.change(item.order, to: status) }
    func autoAssign(_ item: AdminWorkOrderRowItem) { Task { await actions.autoAssign(item.order) } }

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

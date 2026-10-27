//
//  AdminTaskboardViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Taskboard, come la pagina /taskboard della web: gli ordini dello stabilimento attivo in colonne
//  per stato. In kanban le colonne stanno tutte affiancate e le card si trascinano; in lista su telefono si
//  sceglie una colonna alla volta (chip con il conteggio), su schermi larghi si vedono in griglia (la scelta
//  resta sul dispositivo). Le viste per persona e calendario sono nelle estensioni +People e +Calendar. Filtri e ricerca sono locali; lo spostamento di colonna è un PATCH dello stato, subito
//  visibile e annullato se il server rifiuta. "Completed" e "Cancelled" passano dalle azioni rapide degli
//  ordini (note di chiusura, conferma). Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminTaskboardViewModel {
    let backend: AriaBackend
    /// Gli ordini a cui il dettaglio e il form dei WorkOrders si appoggiano: qui fa da anagrafica
    /// (persone, squadre, asset) e da "lista" del dettaglio, senza mai tenere ordini suoi.
    private let workOrders: AdminWorkOrdersViewModel
    /// Completamento e annullamento di un ordine, con i loro fogli.
    let quickActions: AdminWorkOrderQuickActions

    private(set) var orders: [AdminWorkOrder] = []
    private(set) var members: [AdminTaskboardMember] = []
    var selectedStatus: AdminWorkOrderStatus = .planned
    /// Kanban o lista: una preferenza del dispositivo, non si azzera all'uscita dall'account.
    var layout = AdminTaskboardViewModel.savedLayout {
        didSet { UserDefaults.standard.set(layout.rawValue, forKey: Self.layoutKey) }
    }
    var filters = AdminTaskboardFilters()
    var searchText = ""
    /// Il mese a schermo nel calendario e il giorno di cui si vedono le attività.
    var calendarMonth = AdminTaskboardViewModel.startOfMonth(.now)
    var calendarDay = Calendar.current.startOfDay(for: .now)

    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// Il ruolo non può leggere gli ordini: niente "riprova", si spiega.
    private(set) var isForbidden = false
    /// Troppi ordini: si sono scaricati solo i più recenti.
    private(set) var isTruncated = false
    /// Errore dell'ultimo spostamento rifiutato (alert).
    var moveError: String?
    /// Il foglio di creazione aperto.
    var createModel: AdminTaskboardCreateViewModel?
    /// I dettagli aperti, in pila.
    var path: [AdminWorkOrderRoute] = []

    static let pageSize = 200
    static let maxPages = 5
    /// Le colonne, nell'ordine del flusso di lavoro.
    static let columns = AdminWorkOrderStatus.known

    private static let layoutKey = "admin.taskboard.layout"
    private static var savedLayout: AdminTaskboardLayout {
        UserDefaults.standard.string(forKey: layoutKey).flatMap(AdminTaskboardLayout.init(rawValue:)) ?? .kanban
    }

    @ObservationIgnored private var movingIds: Set<String> = []
    @ObservationIgnored private var details: [String: AdminWorkOrderDetailViewModel] = [:]
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var loadedPlantId: String?
    @ObservationIgnored private var membersTask: Task<Void, Never>?

    init(backend: AriaBackend) {
        self.backend = backend
        workOrders = AdminWorkOrdersViewModel(backend: backend)
        quickActions = AdminWorkOrderQuickActions(backend: backend)
        quickActions.onUpdated = { [weak self] order in self?.didUpdate(order) }
    }

    private var api: AdminWorkOrdersAPI { AdminWorkOrdersAPI(api: backend.api) }
    var directory: AdminWorkOrderDirectory { workOrders.directory }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        generation += 1
        membersTask?.cancel()
        membersTask = nil
        workOrders.reset()
        quickActions.reset()
        orders = []
        members = []
        selectedStatus = .planned
        filters = AdminTaskboardFilters()
        searchText = ""
        calendarMonth = Self.startOfMonth(.now)
        calendarDay = Calendar.current.startOfDay(for: .now)
        hasLoaded = false
        isLoading = false
        errorMessage = nil
        isForbidden = false
        isTruncated = false
        moveError = nil
        createModel = nil
        path = []
        movingIds = []
        details = [:]
        loadedPlantId = nil
    }

    // MARK: Caricamento

    /// Cambia con lo stabilimento: la bacheca è sempre dello stabilimento attivo.
    var loadKey: String { backend.activePlantId ?? "" }

    var plantName: String? { backend.activePlantName }

    func loadIfNeeded() async {
        guard !hasLoaded || loadedPlantId != backend.activePlantId else { return }
        await load()
    }

    func refresh() async {
        membersTask?.cancel()
        await load()
    }

    /// Tutti gli ordini dello stabilimento, aperti e chiusi, a pagine di 200 (al massimo `maxPages`).
    func load() async {
        generation += 1
        let current = generation
        let plantId = backend.activePlantId
        isLoading = true
        errorMessage = nil
        startLoadingLookups()
        defer { if current == generation { isLoading = false } }
        do {
            var rows: [AdminWorkOrder] = []
            var truncated = false
            for page in 0..<Self.maxPages {
                let query = AdminWorkOrderQuery(statusGroup: .all, plantId: plantId, limit: Self.pageSize,
                                                offset: page * Self.pageSize)
                let chunk = try await api.list(query)
                guard current == generation else { return }
                let known = Set(rows.map(\.id))
                rows += chunk.filter { !known.contains($0.id) }
                if chunk.count < Self.pageSize { break }
                truncated = page == Self.maxPages - 1
            }
            orders = rows
            isTruncated = truncated
            isForbidden = false
            loadedPlantId = plantId
            if !hasLoaded { selectFirstFilledColumn() }
            hasLoaded = true
        } catch {
            guard current == generation, let message = AdminWorkOrderFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
            isForbidden = AdminWorkOrderFailure.isForbidden(error)
        }
    }

    /// Persone, squadre e asset per i nomi; i membri per il filtro. Facoltativi: se mancano resta quel che c'è.
    private func startLoadingLookups() {
        Task { await workOrders.directory.loadIfNeeded() }
        membersTask?.cancel()
        let backend = backend
        membersTask = Task {
            let rows = try? await backend.api.call(AdminTaskboardAPI.members())
            guard !Task.isCancelled, let rows else { return }
            members = rows.items
        }
    }

    /// La prima volta si apre la colonna con qualcosa dentro, non una vuota.
    private func selectFirstFilledColumn() {
        guard !orders.contains(where: { $0.status == selectedStatus }),
              let first = Self.columns.first(where: { status in orders.contains { $0.status == status } }) else { return }
        selectedStatus = first
    }

    // MARK: Colonne

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Gli ordini che passano filtri e ricerca.
    var visibleOrders: [AdminWorkOrder] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return orders.filter { order in
            guard filters.matches(order) else { return false }
            guard !query.isEmpty else { return true }
            return [order.title, order.assetTag, order.zone, assigneeName(for: order)]
                .contains { $0?.localizedStandardContains(query) == true }
        }
    }

    func count(in status: AdminWorkOrderStatus) -> Int {
        visibleOrders.filter { $0.status == status }.count
    }

    /// Le card di una colonna: prima le più urgenti.
    func cards(in status: AdminWorkOrderStatus) -> [AdminWorkOrderRowItem] {
        AdminWorkOrderSort.priority.sorted(visibleOrders.filter { $0.status == status }).map(card)
    }

    func card(_ order: AdminWorkOrder) -> AdminWorkOrderRowItem {
        let steps = order.stepProgress.flatMap { $0.total > 0 ? $0 : nil }
        return AdminWorkOrderRowItem(
            order: order,
            status: order.status,
            priority: order.priority == .unknown ? nil : order.priority,
            place: AdminWorkOrderFormat.joined([order.assetTag, order.zone]),
            assignee: AdminWorkOrderFormat.joined([assigneeName(for: order), directory.team(order.assignedToTeamId)?.name]),
            due: order.isClosed ? nil : order.dueDate.map(AdminWorkOrderFormat.shortDate),
            isOverdue: order.isOverdue(),
            progress: steps?.fraction,
            progressText: steps.map { "\($0.reported)/\($0.total)" },
            isBusy: movingIds.contains(order.id) || quickActions.isBusy(order)
        )
    }

    func assigneeName(for order: AdminWorkOrder) -> String? {
        members.first { $0.id == order.assignedToUserId }?.displayName ?? directory.assigneeName(for: order)
    }

    // MARK: Filtri

    /// Persone fra cui filtrare: i membri attivi, o le persone dell'anagrafica se i membri non si leggono.
    var memberChoices: [AdminWorkOrderChoice] {
        let people: [AdminWorkOrderChoice] = members.isEmpty
            ? directory.activeUsers.map { AdminWorkOrderChoice(id: $0.id, title: $0.displayName, subtitle: nil) }
            : members.filter(\.isActive).map { AdminWorkOrderChoice(id: $0.id, title: $0.displayName, subtitle: nil) }
        return people.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var teamChoices: [AdminWorkOrderTeam] { directory.teams(in: backend.activePlantId) }

    var memberFilterName: String? {
        filters.memberId.map { id in memberChoices.first { $0.id == id }?.title ?? id }
    }

    var teamFilterName: String? {
        filters.teamId.map { id in directory.team(id)?.name ?? id }
    }

    func clearFilters() { filters = AdminTaskboardFilters() }

    // MARK: Spostamenti

    /// Le colonne in cui si può portare l'ordine ("Verified" solo da "Completed").
    func moveChoices(for item: AdminWorkOrderRowItem) -> [AdminWorkOrderStatus] {
        quickActions.statusChoices(for: item.order)
    }

    func move(_ item: AdminWorkOrderRowItem, to status: AdminWorkOrderStatus) {
        move(item.order, to: status)
    }

    /// Una card trascinata su una colonna della kanban: come "Move to…", solo verso le colonne permesse.
    func drop(_ ids: [String], on status: AdminWorkOrderStatus) -> Bool {
        guard let id = ids.first, !movingIds.contains(id), let order = orders.first(where: { $0.id == id }),
              !quickActions.isBusy(order), quickActions.statusChoices(for: order).contains(status) else { return false }
        move(order, to: status)
        return true
    }

    private func move(_ order: AdminWorkOrder, to status: AdminWorkOrderStatus) {
        switch status {
        case .completed, .cancelled: quickActions.change(order, to: status)
        case .unknown: break
        default: Task { await moveOptimistically(order, to: status) }
        }
    }

    /// La card cambia colonna subito; se il server rifiuta torna com'era e si spiega perché.
    private func moveOptimistically(_ order: AdminWorkOrder, to status: AdminWorkOrderStatus) async {
        guard !movingIds.contains(order.id), let index = orders.firstIndex(where: { $0.id == order.id }) else { return }
        let original = orders[index]
        orders[index].status = status
        movingIds.insert(order.id)
        defer { movingIds.remove(order.id) }
        do {
            didUpdate(try await api.update(order.id, AdminWorkOrderUpdate(status: status.rawValue)))
        } catch {
            if let at = orders.firstIndex(where: { $0.id == order.id }) { orders[at] = original }
            moveError = AdminWorkOrderFailure.message(for: error, backend: backend)
        }
    }

    // MARK: Modifiche

    /// Un ordine salvato dal server: la sua card si aggiorna (o compare, se la bacheca non l'aveva).
    func didUpdate(_ order: AdminWorkOrder) {
        if let index = orders.firstIndex(where: { $0.id == order.id }) {
            orders[index] = order
        } else if order.plantId == nil || backend.activePlantId == nil || order.plantId == backend.activePlantId {
            orders.insert(order, at: 0)
        }
    }

    // MARK: Creazione

    func startCreating() {
        createModel = AdminTaskboardCreateViewModel(backend: backend, status: selectedStatus) { [weak self] order in
            guard let self else { return }
            didUpdate(order)
            if let status = order.status, status != .unknown { selectedStatus = status }
        }
    }

    // MARK: Dettaglio

    /// Il dettaglio dei WorkOrders, uno per ordine finché resta aperto.
    func detailModel(for order: AdminWorkOrder) -> AdminWorkOrderDetailViewModel {
        if let model = details[order.id] { return model }
        let model = workOrders.detailModel(for: order)
        details[order.id] = model
        return model
    }

    /// Un dettaglio si chiude: la sua card prende quello che è cambiato (o sparisce se l'ordine è stato eliminato).
    func pathChanged() {
        let open = Set(path.map(\.order.id))
        for (id, model) in details where !open.contains(id) {
            if model.isDeleted {
                orders.removeAll { $0.id == id }
            } else {
                didUpdate(model.order)
            }
            details[id] = nil
        }
    }
}

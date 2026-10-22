//
//  AdminWorkflowsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Workflows, come la pagina /workflows della web: l'elenco dei flussi dell'azienda (a pagine),
//  col filtro di stato chiesto al server e la ricerca sui flussi già scaricati. Vive in AppViewModel: i dati
//  restano fra un cambio di sezione e l'altro. Il dettaglio e le sue azioni stanno in AdminWorkflowDetailViewModel.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkflowsViewModel {
    let backend: AriaBackend

    /// La lista a schermo, come la dà il server.
    private(set) var flows: [AdminWorkflow] = []
    /// Tutti i flussi visti (anche usciti dalla lista per un cambio di stato): il dettaglio parte da qui.
    private(set) var knownFlows: [String: AdminWorkflow] = [:]
    /// Quanti flussi ci sono in tutto con lo stato scelto.
    private(set) var total: Int?
    /// I tipi di nodo che questo server non può eseguire (da node-kinds; vuoto se la rotta non risponde).
    private(set) var unavailableKinds: Set<String> = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    @ObservationIgnored private var loadedKey: String?
    @ObservationIgnored private var kindsCompanyId: String?

    var searchText = ""
    /// `nil`: tutti gli stati (il parametro non si manda).
    var statusFilter: AdminWorkflowStatus?

    // MARK: Navigazione e fogli

    /// I flussi aperti nello stack (id), dal primo all'ultimo.
    var path: [String] = []
    /// Il modulo di creazione aperto (sheet).
    var newFlowForm: AdminWorkflowFormViewModel?

    static let pageSize = 50

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// Cambia quando va richiesta la lista: azienda o stato scelto (la vista ci appende un `.task`).
    var loadKey: String { "\(backend.activeCompanyId ?? "-")|\(statusFilter?.rawValue ?? "all")" }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var visibleFlows: [AdminWorkflow] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return flows }
        return flows.filter {
            [$0.name, $0.description].compactMap { $0 }.contains { $0.localizedStandardContains(query) }
        }
    }

    var statusFilterLabel: String { statusFilter?.label ?? String(localized: "All") }

    var subtitle: String {
        let count = visibleFlows.count
        guard let total, !isSearching, total > count else { return String(localized: "\(count) flows") }
        return String(localized: "\(count) of \(total) flows")
    }

    var canCreate: Bool { backend.activeCompanyId != nil }

    // MARK: Caricamento

    var canLoadMore: Bool {
        guard hasLoaded, let total else { return false }
        return flows.count < total
    }

    func load() async {
        guard let companyId = backend.activeCompanyId else {
            errorMessage = AriaError.missingCompany.localizedDescription
            return
        }
        let key = loadKey
        // Altra azienda o altro stato: la lista vecchia non vale, non si mostra mentre arriva la nuova.
        if key != loadedKey {
            flows = []
            total = nil
            hasLoaded = false
            errorMessage = nil
            loadedKey = key
        }
        isLoading = true
        defer { isLoading = false }
        async let kindsLoad: Void = loadNodeKinds(companyId: companyId)
        do {
            let page = try await backend.api.call(AdminWorkflowsAPI.flows(
                companyId: companyId, status: statusFilter?.rawValue, limit: Self.pageSize, skip: 0))
            // Lo stato è cambiato durante la richiesta: questa risposta non vale più.
            guard key == loadKey, !Task.isCancelled else { await kindsLoad; return }
            flows = page.flows
            total = page.total
            remember(page.flows)
            hasLoaded = true
            errorMessage = nil
            lastUpdated = .now
        } catch {
            if key == loadKey, let message = AdminWorkflowFailure.message(for: error, backend: backend) {
                errorMessage = message
            }
        }
        await kindsLoad
    }

    /// La pagina dopo: si aggiunge in fondo, senza doppioni (un flusso nuovo sposta gli offset).
    func loadMore() async {
        guard canLoadMore, !isLoadingMore, let companyId = backend.activeCompanyId else { return }
        let key = loadKey
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await backend.api.call(AdminWorkflowsAPI.flows(
                companyId: companyId, status: statusFilter?.rawValue, limit: Self.pageSize, skip: flows.count))
            guard key == loadKey else { return }
            let known = Set(flows.map(\.id))
            let fresh = page.flows.filter { !known.contains($0.id) }
            flows += fresh
            errorMessage = nil
            if let pageTotal = page.total { total = pageTotal }
            // Pagina vuota: il totale era vecchio, non si chiede altro.
            if page.flows.isEmpty { total = flows.count }
            remember(fresh)
        } catch {
            if key == loadKey { errorMessage = AdminWorkflowFailure.message(for: error, backend: backend) }
        }
    }

    /// I tipi di nodo servono solo a segnalare quelli non disponibili: se la rotta non risponde, niente errori.
    private func loadNodeKinds(companyId: String) async {
        guard kindsCompanyId != companyId else { return }
        guard let rows = try? await backend.api.call(AdminWorkflowsAPI.nodeKinds()) else { return }
        unavailableKinds = Set(rows.items.filter { !$0.available }.map(\.kind))
        kindsCompanyId = companyId
    }

    private func remember(_ rows: [AdminWorkflow]) {
        for flow in rows { knownFlows[flow.id] = flow }
    }

    // MARK: Dopo una modifica

    /// Un flusso creato, modificato o cambiato di stato: la lista si aggiorna senza ricaricarla.
    /// Se ora ha un altro stato da quello filtrato, esce dalla lista (il dettaglio lo vede ancora).
    func apply(_ flow: AdminWorkflow) {
        knownFlows[flow.id] = flow
        let matches = statusFilter == nil || flow.knownStatus == statusFilter
        if let index = flows.firstIndex(where: { $0.id == flow.id }) {
            if matches {
                flows[index] = flow
            } else {
                flows.remove(at: index)
                total = total.map { max($0 - 1, 0) }
            }
        } else if matches, hasLoaded {
            flows.insert(flow, at: 0)
            total = total.map { $0 + 1 }
        }
    }

    func remove(id: String) {
        if flows.contains(where: { $0.id == id }) { total = total.map { max($0 - 1, 0) } }
        flows.removeAll { $0.id == id }
        knownFlows[id] = nil
    }

    func makeDetailViewModel(flowId: String) -> AdminWorkflowDetailViewModel {
        AdminWorkflowDetailViewModel(list: self, flowId: flowId)
    }

    func startCreating() {
        newFlowForm = AdminWorkflowFormViewModel(backend: backend, editing: nil, reload: nil)
    }

    /// Un flusso creato: entra in lista e si apre.
    func didCreate(_ flow: AdminWorkflow) {
        apply(flow)
        path.append(flow.id)
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        flows = []
        knownFlows = [:]
        total = nil
        unavailableKinds = []
        isLoading = false
        isLoadingMore = false
        hasLoaded = false
        errorMessage = nil
        lastUpdated = nil
        loadedKey = nil
        kindsCompanyId = nil
        searchText = ""
        statusFilter = nil
        path = []
        newFlowForm = nil
    }
}

//
//  AdminMaintenanceViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Maintenance, come la pagina /maintenance della web: i piani di manutenzione preventiva.
//  Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//  Lo stato si chiede al server (senza, il server dà solo gli approvati); stabilimento, asset, frequenza,
//  scadenza e ricerca filtrano qui, subito, sui piani già scaricati.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMaintenanceViewModel {
    let backend: AriaBackend

    private(set) var plans: [AdminMaintenancePlan] = []
    private(set) var isLoading = false
    /// La lista è arrivata almeno una volta per lo stato scelto.
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    /// Il `loadKey` della lista a schermo.
    @ObservationIgnored private var loadedKey: String?
    /// Quando rileggere entrando nella sezione (vedi AriaFreshness).
    @ObservationIgnored private var freshness = AriaFreshness()
    /// Sale a ogni modifica di `plans`: è la chiave che invalida le liste calcolate.
    private var plansRevision = 0

    /// Il testo del campo di ricerca (legato alla vista); i filtri usano `appliedQuery`, che lo segue con ritardo.
    var searchText = ""
    /// La ricerca applicata alla lista, già senza spazi ai bordi.
    private(set) var appliedQuery = ""
    @ObservationIgnored private let searchDebouncer = AriaDebouncer()
    var statusFilter: AdminMaintenanceStatus = .approved
    /// La scelta esplicita dello stabilimento (vedi `plantFilter`). Senza scelta vale quello attivo dell'app.
    private var hasChosenPlant = false
    private var chosenPlant: String?
    /// Lo stabilimento attivo quando l'utente ha scelto: se cambia, una scelta di uno stabilimento decade.
    private var activePlantAtChoice: String?
    var assetFilter: String?
    var frequencyFilter: AdminMaintenanceFrequency?
    var dueFilter: AdminMaintenanceDueState?

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// Cambia quando va richiesta la lista: azienda o stato scelto (la vista ci appende un `.task`).
    var loadKey: String { "\(backend.activeCompanyId ?? "-")|\(statusFilter.rawValue)" }

    // MARK: Filtri

    var plants: [AriaPlant] { backend.plants }
    /// Senza scelta esplicita vale lo stabilimento attivo. "All sites" (`nil`) resta finché non si azzera;
    /// uno stabilimento scelto vale finché lo stabilimento attivo non cambia (poi si torna al nuovo attivo).
    var plantFilter: String? {
        get {
            guard hasChosenPlant, chosenPlant == nil || activePlantAtChoice == backend.activePlantId else {
                return backend.activePlantId
            }
            return chosenPlant
        }
        set {
            chosenPlant = newValue
            activePlantAtChoice = backend.activePlantId
            hasChosenPlant = true
        }
    }

    /// Il filtro stabilimento è diverso dal predefinito (lo stabilimento attivo): la chip si evidenzia.
    var isPlantFilterCustom: Bool { plantFilter != backend.activePlantId }

    /// Ciò che serve alla vista, calcolato una volta per ogni combinazione di ingressi.
    private struct Derived {
        var assetTags: [String] = []
        /// Tutti i filtri tranne la scadenza: sono i piani su cui contano le tile.
        var filteredCount = 0
        var dueCounts: [AdminMaintenanceDueState: Int] = [:]
        /// Per scadenza (le più vicine in alto, quelle senza data in fondo), poi per nome.
        var visible: [AdminMaintenancePlan] = []
    }

    private struct DerivedKey: Equatable {
        let revision: Int
        let plant: String?
        let asset: String?
        let frequency: AdminMaintenanceFrequency?
        let due: AdminMaintenanceDueState?
        let query: String
        /// La scadenza dipende dall'ora: si ricalcola almeno una volta all'ora.
        let hour: Int
    }

    @ObservationIgnored private var derivedKey: DerivedKey?
    @ObservationIgnored private var derivedCache = Derived()

    /// Leggere gli ingressi qui dentro li fa osservare alla vista; il calcolo vero avviene solo a cache vuota.
    private var derived: Derived {
        let key = DerivedKey(revision: plansRevision, plant: plantFilter, asset: assetFilter,
                             frequency: frequencyFilter, due: dueFilter, query: appliedQuery,
                             hour: Int(Date.now.timeIntervalSince1970 / 3600))
        if derivedKey != key {
            derivedCache = computeDerived(for: key)
            derivedKey = key
        }
        return derivedCache
    }

    private func computeDerived(for key: DerivedKey) -> Derived {
        // Piani dello stabilimento scelto; quelli senza `plant_id` valgono per tutti.
        let plantPlans = key.plant.map { plant in plans.filter { $0.plantId == nil || $0.plantId == plant } } ?? plans
        let assetTags = Set(plantPlans.compactMap(\.assetTag)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let filtered = plantPlans
            .filter { key.asset == nil || $0.assetTag == key.asset }
            .filter { key.frequency == nil || $0.frequency == key.frequency?.rawValue }
            .filter { key.query.isEmpty || $0.searchableFields.contains { $0.localizedStandardContains(key.query) } }
        var counts: [AdminMaintenanceDueState: Int] = [:]
        var withState: [(plan: AdminMaintenancePlan, state: AdminMaintenanceDueState)] = []
        withState.reserveCapacity(filtered.count)
        for plan in filtered {
            let state = plan.dueState
            counts[state, default: 0] += 1
            withState.append((plan, state))
        }
        let visible = withState
            .filter { key.due == nil || $0.state == key.due }
            .map { $0.plan }
            .sorted { a, b in
                switch (a.nextDueAt, b.nextDueAt) {
                case let (x?, y?) where x != y: x < y
                case (_?, nil): true
                case (nil, _?): false
                default: a.name.localizedStandardCompare(b.name) == .orderedAscending
                }
            }
        return Derived(assetTags: assetTags, filteredCount: filtered.count, dueCounts: counts, visible: visible)
    }

    /// Gli asset dei piani dello stabilimento, per il filtro.
    var assetTags: [String] { derived.assetTags }

    var visiblePlans: [AdminMaintenancePlan] { derived.visible }

    /// Chiamata a ogni cambio del testo: svuotato si applica subito, altrimenti dopo una pausa di battitura.
    func searchTextChanged() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != appliedQuery else {
            searchDebouncer.cancel()
            return
        }
        if query.isEmpty {
            searchDebouncer.flush { appliedQuery = "" }
        } else {
            searchDebouncer.schedule { [weak self] in self?.applySearch() }
        }
    }

    private func applySearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query != appliedQuery { appliedQuery = query }
    }

    var isSearching: Bool { !appliedQuery.isEmpty }
    var hasLocalFilters: Bool {
        assetFilter != nil || frequencyFilter != nil || dueFilter != nil || isPlantFilterCustom
    }

    func clearFilters() {
        assetFilter = nil
        frequencyFilter = nil
        dueFilter = nil
        resetPlantChoice()
    }

    private func resetPlantChoice() {
        hasChosenPlant = false
        chosenPlant = nil
        activePlantAtChoice = nil
    }

    var plantFilterLabel: String {
        guard let plantFilter else { return String(localized: "All sites") }
        return plants.first { $0.id == plantFilter }?.name ?? plantFilter
    }
    var assetFilterLabel: String { assetFilter ?? String(localized: "All assets") }
    var frequencyFilterLabel: String { frequencyFilter?.label ?? String(localized: "All") }

    // MARK: Tile

    var totalCount: Int { derived.filteredCount }

    func count(_ state: AdminMaintenanceDueState) -> Int {
        derived.dueCounts[state] ?? 0
    }

    /// Un tocco su una tile filtra la lista; un secondo tocco toglie il filtro.
    func toggleDueFilter(_ state: AdminMaintenanceDueState) {
        dueFilter = dueFilter == state ? nil : state
    }

    var subtitle: String {
        let count = visiblePlans.count
        return String(localized: "\(count) plans")
    }

    // MARK: Caricamento

    /// Entrando nella sezione: rilegge solo la prima volta, cambiati azienda o stato, o se i dati sono vecchi.
    /// I dati già a schermo restano mentre arrivano i nuovi.
    func loadIfNeeded() async {
        guard loadKey != loadedKey || freshness.isStale() else { return }
        await load()
    }

    /// Lettura forzata (tirare per aggiornare, "Retry").
    func load() async {
        let status = statusFilter
        // Altra azienda o altro stato: la lista vecchia non vale, non si mostra mentre arriva la nuova.
        let key = loadKey
        if key != loadedKey {
            plans = []
            plansRevision &+= 1
            hasLoaded = false
            errorMessage = nil
            loadedKey = key
            freshness.invalidate()
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await backend.api.call(AdminMaintenanceAPI.plans(status: status.rawValue))
            // Lo stato è cambiato durante la richiesta: questa risposta non vale più.
            guard status == statusFilter, !Task.isCancelled else { return }
            plans = response.items
            plansRevision &+= 1
            hasLoaded = true
            freshness.markLoaded()
            errorMessage = nil
            lastUpdated = .now
            if let asset = assetFilter, !assetTags.contains(asset) { assetFilter = nil }
        } catch {
            guard status == statusFilter, let message = AdminMaintenanceFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
            freshness.invalidate()
        }
    }

    // MARK: Dopo una modifica

    /// Un piano creato o modificato altrove (form, dettaglio): si aggiorna la lista senza ricaricarla.
    /// Se ora ha un altro stato da quello filtrato, esce dalla lista.
    func apply(_ plan: AdminMaintenancePlan) {
        plans.removeAll { $0.id == plan.id }
        if plan.status == nil || plan.status == statusFilter.rawValue { plans.append(plan) }
        plansRevision &+= 1
        freshness.invalidate()
    }

    /// Un piano eliminato dal dettaglio: esce dalla lista.
    func remove(_ plan: AdminMaintenancePlan) {
        plans.removeAll { $0.id == plan.id }
        plansRevision &+= 1
        freshness.invalidate()
    }

    /// `plant_id` è obbligatorio alla creazione.
    var canCreate: Bool { backend.activePlantId != nil || !backend.plants.isEmpty }

    func makeDetailViewModel(for plan: AdminMaintenancePlan) -> AdminMaintenanceDetailViewModel {
        AdminMaintenanceDetailViewModel(backend: backend, plan: plan,
                                        onChange: { [weak self] in self?.apply($0) },
                                        onDelete: { [weak self] in self?.remove($0) })
    }

    func makeFormViewModel() -> AdminMaintenanceFormViewModel {
        AdminMaintenanceFormViewModel(backend: backend, editing: nil)
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        plans = []
        plansRevision &+= 1
        freshness.invalidate()
        searchDebouncer.cancel()
        appliedQuery = ""
        isLoading = false
        hasLoaded = false
        errorMessage = nil
        lastUpdated = nil
        loadedKey = nil
        searchText = ""
        statusFilter = .approved
        resetPlantChoice()
        assetFilter = nil
        frequencyFilter = nil
        dueFilter = nil
    }
}

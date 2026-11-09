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

    var searchText = ""
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
    /// Senza scelta esplicita vale lo stabilimento attivo. "All plants" (`nil`) resta finché non si azzera;
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

    /// Piani dello stabilimento scelto; quelli senza `plant_id` valgono per tutti.
    private var plantPlans: [AdminMaintenancePlan] {
        guard let plant = plantFilter else { return plans }
        return plans.filter { $0.plantId == nil || $0.plantId == plant }
    }

    /// Gli asset dei piani dello stabilimento, per il filtro.
    var assetTags: [String] {
        Set(plantPlans.compactMap(\.assetTag)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Tutti i filtri tranne la scadenza: sono i piani su cui contano le tile.
    private var filteredPlans: [AdminMaintenancePlan] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return plantPlans
            .filter { assetFilter == nil || $0.assetTag == assetFilter }
            .filter { frequencyFilter == nil || $0.frequency == frequencyFilter?.rawValue }
            .filter { query.isEmpty || $0.searchableFields.contains { $0.localizedStandardContains(query) } }
    }

    /// Per scadenza (le più vicine in alto, quelle senza data in fondo), poi per nome.
    var visiblePlans: [AdminMaintenancePlan] {
        filteredPlans
            .filter { dueFilter == nil || $0.dueState == dueFilter }
            .sorted { a, b in
                switch (a.nextDueAt, b.nextDueAt) {
                case let (x?, y?) where x != y: x < y
                case (_?, nil): true
                case (nil, _?): false
                default: a.name.localizedStandardCompare(b.name) == .orderedAscending
                }
            }
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
        guard let plantFilter else { return String(localized: "All plants") }
        return plants.first { $0.id == plantFilter }?.name ?? plantFilter
    }
    var assetFilterLabel: String { assetFilter ?? String(localized: "All assets") }
    var frequencyFilterLabel: String { frequencyFilter?.label ?? String(localized: "All") }

    // MARK: Tile

    var totalCount: Int { filteredPlans.count }

    func count(_ state: AdminMaintenanceDueState) -> Int {
        filteredPlans.filter { $0.dueState == state }.count
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

    func load() async {
        let status = statusFilter
        // Altra azienda o altro stato: la lista vecchia non vale, non si mostra mentre arriva la nuova.
        let key = loadKey
        if key != loadedKey {
            plans = []
            hasLoaded = false
            errorMessage = nil
            loadedKey = key
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await backend.api.call(AdminMaintenanceAPI.plans(status: status.rawValue))
            // Lo stato è cambiato durante la richiesta: questa risposta non vale più.
            guard status == statusFilter, !Task.isCancelled else { return }
            plans = response.items
            hasLoaded = true
            errorMessage = nil
            lastUpdated = .now
            if let asset = assetFilter, !assetTags.contains(asset) { assetFilter = nil }
        } catch {
            guard status == statusFilter, let message = AdminMaintenanceFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }

    // MARK: Dopo una modifica

    /// Un piano creato o modificato altrove (form, dettaglio): si aggiorna la lista senza ricaricarla.
    /// Se ora ha un altro stato da quello filtrato, esce dalla lista.
    func apply(_ plan: AdminMaintenancePlan) {
        plans.removeAll { $0.id == plan.id }
        if plan.status == nil || plan.status == statusFilter.rawValue { plans.append(plan) }
    }

    /// `plant_id` è obbligatorio alla creazione.
    var canCreate: Bool { backend.activePlantId != nil || !backend.plants.isEmpty }

    func makeDetailViewModel(for plan: AdminMaintenancePlan) -> AdminMaintenanceDetailViewModel {
        AdminMaintenanceDetailViewModel(backend: backend, plan: plan) { [weak self] in self?.apply($0) }
    }

    func makeFormViewModel() -> AdminMaintenanceFormViewModel {
        AdminMaintenanceFormViewModel(backend: backend, editing: nil)
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        plans = []
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

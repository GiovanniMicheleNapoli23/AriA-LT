//
//  AdminAssetsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli asset dello stabilimento, come la pagina /assets della web.
//  Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//  Lo stato si chiede al server (senza, il server dà solo gli approvati); tipo, zona, ricerca e
//  stabilimento attivo filtrano qui, subito, sugli asset già scaricati.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAssetsViewModel {
    let backend: AriaBackend

    private(set) var assets: [AdminAsset] = []
    private(set) var isLoading = false
    /// La lista è arrivata almeno una volta per lo stato scelto.
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    /// Il `loadKey` della lista a schermo.
    @ObservationIgnored private var loadedKey: String?
    /// Quando rileggere entrando nella sezione (vedi AriaFreshness).
    @ObservationIgnored private var freshness = AriaFreshness()
    /// Sale a ogni modifica di `assets`: è la chiave che invalida le liste calcolate.
    private var assetsRevision = 0

    /// Il testo del campo di ricerca (legato alla vista); i filtri usano `appliedQuery`, che lo segue con ritardo.
    var searchText = ""
    /// La ricerca applicata alla lista, già senza spazi ai bordi.
    private(set) var appliedQuery = ""
    @ObservationIgnored private let searchDebouncer = AriaDebouncer()
    var statusFilter: AdminAssetStatus = .approved
    var typeFilter: AdminAssetType?
    var zoneFilter: String?

    /// Selezione e approvazione in blocco delle bozze; la logica è in AdminAssetsViewModel+Approval.
    var isSelecting = false
    var selection: Set<String> = []
    var showsApproveConfirmation = false
    var isApproving = false
    var approveError: String?
    /// L'esito dell'ultima approvazione in blocco.
    var notice: String?

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// Cambia quando va richiesta la lista: azienda o stato scelto (la vista ci appende un `.task`).
    var loadKey: String { "\(backend.activeCompanyId ?? "-")|\(statusFilter.rawValue)" }

    // MARK: Filtri

    /// Ciò che serve alla lista: righe visibili e zone. Si ricalcola solo se cambia uno degli ingressi.
    private struct Derived {
        var visible: [AdminAsset] = []
        var zones: [String] = []
    }

    private struct DerivedKey: Equatable {
        let revision: Int
        let plant: String?
        let type: AdminAssetType?
        let zone: String?
        let query: String
    }

    @ObservationIgnored private var derivedKey: DerivedKey?
    @ObservationIgnored private var derivedCache = Derived()

    /// Leggere gli ingressi qui dentro li fa osservare alla vista; il calcolo vero avviene solo a cache vuota.
    private var derived: Derived {
        let key = DerivedKey(revision: assetsRevision, plant: backend.activePlantId, type: typeFilter,
                             zone: zoneFilter, query: appliedQuery)
        if derivedKey != key {
            derivedCache = computeDerived(for: key)
            derivedKey = key
        }
        return derivedCache
    }

    private func computeDerived(for key: DerivedKey) -> Derived {
        // Asset dello stabilimento attivo; quelli senza `plant_id` valgono per tutti.
        let plantAssets = key.plant.map { plant in assets.filter { $0.plantId == nil || $0.plantId == plant } } ?? assets
        let zones = Set(plantAssets.compactMap(\.zone)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let visible = plantAssets
            .filter { key.type == nil || $0.assetType == key.type?.rawValue }
            .filter { key.zone == nil || $0.zone == key.zone }
            .filter { key.query.isEmpty || $0.searchableFields.contains { $0.localizedStandardContains(key.query) } }
            .sorted { $0.tag.localizedStandardCompare($1.tag) == .orderedAscending }
        return Derived(visible: visible, zones: zones)
    }

    /// Le zone degli asset scaricati, per il filtro.
    var zones: [String] { derived.zones }

    var visibleAssets: [AdminAsset] { derived.visible }

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
    var hasLocalFilters: Bool { typeFilter != nil || zoneFilter != nil }

    func clearFilters() {
        typeFilter = nil
        zoneFilter = nil
    }

    var typeFilterLabel: String { typeFilter?.label ?? String(localized: "All types") }
    var zoneFilterLabel: String { zoneFilter ?? String(localized: "All zones") }

    var subtitle: String {
        let count = visibleAssets.count
        return String(localized: "\(count) assets")
    }

    // MARK: Caricamento

    /// Entrando nella sezione: rilegge solo la prima volta, cambiati azienda o stato, o se i dati sono vecchi.
    /// I dati già a schermo restano mentre arrivano i nuovi.
    func loadIfNeeded() async {
        guard loadKey != loadedKey || freshness.isStale() else { return }
        await load()
    }

    /// Lettura forzata (tirare per aggiornare, "Retry", dopo un'approvazione).
    func load() async {
        let status = statusFilter
        // Altra azienda o altro stato: la lista vecchia non vale, non si mostra mentre arriva la nuova.
        let key = loadKey
        if key != loadedKey {
            assets = []
            assetsRevision &+= 1
            hasLoaded = false
            errorMessage = nil
            loadedKey = key
            freshness.invalidate()
            endSelecting()
            notice = nil
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await backend.api.call(AdminAssetsAPI.assets(status: status.rawValue))
            // Lo stato è cambiato durante la richiesta: questa risposta non vale più.
            guard status == statusFilter, !Task.isCancelled else { return }
            assets = response.items
            assetsRevision &+= 1
            hasLoaded = true
            freshness.markLoaded()
            errorMessage = nil
            lastUpdated = .now
            if let zone = zoneFilter, !zones.contains(zone) { zoneFilter = nil }
        } catch {
            guard status == statusFilter, let message = AdminAssetsFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
            freshness.invalidate()
        }
    }

    // MARK: Dopo una modifica

    /// Un asset eliminato dal dettaglio: esce dalla lista.
    func remove(_ asset: AdminAsset) {
        assets.removeAll { $0.id == asset.id || $0.tag == asset.tag }
        assetsRevision &+= 1
        freshness.invalidate()
        selection.remove(asset.id)
    }

    /// Un asset creato o modificato altrove (form, dettaglio): si aggiorna la lista senza ricaricarla.
    /// Se ora ha un altro stato da quello filtrato, esce dalla lista.
    func apply(_ asset: AdminAsset) {
        assets.removeAll { $0.id == asset.id || $0.tag == asset.tag }
        if asset.status == nil || asset.status == statusFilter.rawValue { assets.append(asset) }
        assetsRevision &+= 1
        freshness.invalidate()
    }

    var canCreate: Bool { backend.activePlantId != nil || !backend.plants.isEmpty }

    func makeDetailViewModel(for asset: AdminAsset) -> AdminAssetDetailViewModel {
        AdminAssetDetailViewModel(backend: backend, asset: asset,
                                  onAssetChanged: { [weak self] in self?.apply($0) },
                                  onAssetDeleted: { [weak self] in self?.remove($0) })
    }

    func makeFormViewModel() -> AdminAssetFormViewModel {
        AdminAssetFormViewModel(backend: backend, editing: nil)
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        assets = []
        assetsRevision &+= 1
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
        typeFilter = nil
        zoneFilter = nil
        endSelecting()
        showsApproveConfirmation = false
        isApproving = false
        approveError = nil
        notice = nil
    }
}

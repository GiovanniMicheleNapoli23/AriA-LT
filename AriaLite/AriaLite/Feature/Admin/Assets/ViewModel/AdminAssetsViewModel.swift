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

    var searchText = ""
    var statusFilter: AdminAssetStatus = .approved
    var typeFilter: AdminAssetType?
    var zoneFilter: String?

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// Cambia quando va richiesta la lista: azienda o stato scelto (la vista ci appende un `.task`).
    var loadKey: String { "\(backend.activeCompanyId ?? "-")|\(statusFilter.rawValue)" }

    // MARK: Filtri

    /// Asset dello stabilimento attivo; quelli senza `plant_id` valgono per tutti.
    private var plantAssets: [AdminAsset] {
        guard let plant = backend.activePlantId else { return assets }
        return assets.filter { $0.plantId == nil || $0.plantId == plant }
    }

    /// Le zone degli asset scaricati, per il filtro.
    var zones: [String] {
        Set(plantAssets.compactMap(\.zone)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var visibleAssets: [AdminAsset] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return plantAssets
            .filter { typeFilter == nil || $0.assetType == typeFilter?.rawValue }
            .filter { zoneFilter == nil || $0.zone == zoneFilter }
            .filter { query.isEmpty || $0.searchableFields.contains { $0.localizedStandardContains(query) } }
            .sorted { $0.tag.localizedStandardCompare($1.tag) == .orderedAscending }
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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

    func load() async {
        let status = statusFilter
        // Altra azienda o altro stato: la lista vecchia non vale, non si mostra mentre arriva la nuova.
        let key = loadKey
        if key != loadedKey {
            assets = []
            hasLoaded = false
            errorMessage = nil
            loadedKey = key
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await backend.api.call(AdminAssetsAPI.assets(status: status.rawValue))
            // Lo stato è cambiato durante la richiesta: questa risposta non vale più.
            guard status == statusFilter, !Task.isCancelled else { return }
            assets = response.items
            hasLoaded = true
            errorMessage = nil
            lastUpdated = .now
            if let zone = zoneFilter, !zones.contains(zone) { zoneFilter = nil }
        } catch {
            guard status == statusFilter, let message = AdminAssetsFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }

    // MARK: Dopo una modifica

    /// Un asset creato o modificato altrove (form, dettaglio): si aggiorna la lista senza ricaricarla.
    /// Se ora ha un altro stato da quello filtrato, esce dalla lista.
    func apply(_ asset: AdminAsset) {
        assets.removeAll { $0.id == asset.id || $0.tag == asset.tag }
        if asset.status == nil || asset.status == statusFilter.rawValue { assets.append(asset) }
    }

    var canCreate: Bool { backend.activePlantId != nil || !backend.plants.isEmpty }

    func makeDetailViewModel(for asset: AdminAsset) -> AdminAssetDetailViewModel {
        AdminAssetDetailViewModel(backend: backend, asset: asset) { [weak self] in self?.apply($0) }
    }

    func makeFormViewModel() -> AdminAssetFormViewModel {
        AdminAssetFormViewModel(backend: backend, editing: nil)
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        assets = []
        isLoading = false
        hasLoaded = false
        errorMessage = nil
        lastUpdated = nil
        loadedKey = nil
        searchText = ""
        statusFilter = .approved
        typeFilter = nil
        zoneFilter = nil
    }
}

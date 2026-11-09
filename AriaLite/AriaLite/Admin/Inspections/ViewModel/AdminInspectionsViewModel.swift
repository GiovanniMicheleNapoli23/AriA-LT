//
//  AdminInspectionsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Inspections, come la pagina /inspections della web.
//  Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//  Il server dà la lista intera senza parametri: ricerca e filtri (stato, stabilimento, asset, area, data)
//  si applicano qui, subito, sulle ispezioni già scaricate.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminInspectionsViewModel {
    let backend: AriaBackend

    private(set) var inspections: [AdminInspection] = []
    private(set) var isLoading = false
    /// La lista è arrivata almeno una volta per l'azienda a schermo.
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    /// Il `loadKey` della lista a schermo.
    @ObservationIgnored private var loadedKey: String?

    var searchText = ""
    /// Valore grezzo dello stato (`nil` = tutti): gli stati disponibili sono quelli presenti nei dati.
    var statusFilter: String?
    /// La scelta esplicita dello stabilimento (vedi `plantFilter`). Senza scelta vale quello attivo dell'app.
    private var hasChosenPlant = false
    private var chosenPlant: String?
    /// Lo stabilimento attivo quando l'utente ha scelto: se cambia, una scelta di uno stabilimento decade.
    private var activePlantAtChoice: String?
    var assetFilter: String?
    var zoneFilter: String?
    var dueFilter: AdminInspectionDueFilter = .any

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// Cambia quando va richiesta la lista: l'azienda attiva (la vista ci appende un `.task`).
    var loadKey: String { backend.activeCompanyId ?? "-" }

    // MARK: Valori dei filtri

    var plants: [AriaPlant] { backend.plants }

    /// Lo stabilimento filtrato (`nil` = tutti). Di default è quello attivo dell'app, come Assets e Documents.
    /// "All plants" scelto dall'utente resta; uno stabilimento scelto vale finché lo stabilimento attivo non cambia.
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

    /// Il filtro stabilimento è diverso dal predefinito (lo stabilimento attivo).
    var isPlantFilterCustom: Bool { plantFilter != backend.activePlantId }

    var statusOptions: [String] {
        // Sinonimi del server (`done`, `completed`) diventano una sola scelta.
        let present = inspections.compactMap(\.status).map { AdminInspectionStatus(raw: $0)?.rawValue ?? $0 }
        return Set(present).sorted { Self.statusRank($0) < Self.statusRank($1) }
    }

    var assetOptions: [String] { distinct(\.assetTag) }
    var zoneOptions: [String] { distinct(\.zone) }

    private func distinct(_ key: KeyPath<AdminInspection, String?>) -> [String] {
        Set(inspections.compactMap { $0[keyPath: key] }).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Ordine degli stati nel menu: da fare, in corso, finite, poi gli sconosciuti.
    private static func statusRank(_ raw: String) -> Int {
        AdminInspectionStatus(raw: raw).flatMap { AdminInspectionStatus.allCases.firstIndex(of: $0) } ?? 99
    }

    // MARK: Lista filtrata

    var visibleInspections: [AdminInspection] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date.now
        return inspections
            .filter(matchesStatus)
            .filter(matchesPlant)
            .filter { assetFilter == nil || $0.assetTag == assetFilter }
            .filter { zoneFilter == nil || $0.zone == zoneFilter }
            .filter { dueFilter.matches($0, now: now) }
            .filter { query.isEmpty || $0.searchableFields.contains { $0.localizedStandardContains(query) } }
            .sorted(by: Self.isOrderedBefore)
    }

    /// Le ispezioni senza stabilimento valgono per tutti (come gli asset senza `plant_id`).
    private func matchesPlant(_ inspection: AdminInspection) -> Bool {
        guard let plant = plantFilter else { return true }
        return inspection.plantId == nil || inspection.plantId == plant
    }

    private func matchesStatus(_ inspection: AdminInspection) -> Bool {
        guard let filter = statusFilter else { return true }
        if let known = AdminInspectionStatus(raw: filter) { return inspection.knownStatus == known }
        return inspection.status == filter
    }

    /// Prima le aperte, per scadenza (senza data in fondo); poi le chiuse, le più recenti prima.
    private static func isOrderedBefore(_ a: AdminInspection, _ b: AdminInspection) -> Bool {
        if a.isClosed != b.isClosed { return !a.isClosed }
        if a.isClosed {
            return (a.completedAt ?? a.updatedAt ?? .distantPast) > (b.completedAt ?? b.updatedAt ?? .distantPast)
        }
        switch (a.dueDate, b.dueDate) {
        case let (x?, y?): return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return a.title.localizedStandardCompare(b.title) == .orderedAscending
        }
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasFilters: Bool {
        statusFilter != nil || isPlantFilterCustom || assetFilter != nil || zoneFilter != nil || dueFilter != .any
    }

    func clearFilters() {
        statusFilter = nil
        hasChosenPlant = false
        chosenPlant = nil
        activePlantAtChoice = nil
        assetFilter = nil
        zoneFilter = nil
        dueFilter = .any
    }

    var statusFilterLabel: String { statusFilter.map(AdminInspectionStatus.label(for:)) ?? String(localized: "All") }
    var plantFilterLabel: String { plantFilter.map(plantName) ?? String(localized: "All plants") }
    var assetFilterLabel: String { assetFilter ?? String(localized: "All assets") }
    var zoneFilterLabel: String { zoneFilter ?? String(localized: "All areas") }

    func plantName(_ id: String) -> String { plants.first { $0.id == id }?.name ?? id }

    // MARK: Riepilogo

    var summary: AdminInspectionCounts { AdminInspectionCounts(visibleInspections) }

    var subtitle: String {
        let count = visibleInspections.count
        return String(localized: "\(count) inspections")
    }

    // MARK: Caricamento

    func load() async {
        // Un'altra azienda: la lista vecchia non vale, non si mostra mentre arriva la nuova.
        let key = loadKey
        if key != loadedKey {
            inspections = []
            hasLoaded = false
            errorMessage = nil
            loadedKey = key
            clearFilters()
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await backend.api.call(AdminInspectionsAPI.list())
            guard key == loadKey, !Task.isCancelled else { return }
            inspections = response.items
            hasLoaded = true
            errorMessage = nil
            lastUpdated = .now
            dropStaleFilters()
        } catch {
            guard key == loadKey, let message = AdminInspectionsFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }

    /// Un filtro su un valore che non c'è più nei dati (ispezione eliminata) non lascia la lista vuota.
    private func dropStaleFilters() {
        if let status = statusFilter, !statusOptions.contains(status) { statusFilter = nil }
        if let asset = assetFilter, !assetOptions.contains(asset) { assetFilter = nil }
        if let zone = zoneFilter, !zoneOptions.contains(zone) { zoneFilter = nil }
    }

    // MARK: Dopo una modifica

    /// Un'ispezione creata o modificata altrove (form, dettaglio): la lista si aggiorna senza ricaricarla.
    func apply(_ inspection: AdminInspection) {
        if let index = inspections.firstIndex(where: { $0.id == inspection.id }) {
            inspections[index] = inspection
        } else {
            inspections.append(inspection)
        }
        hasLoaded = true
    }

    func remove(id: String) {
        inspections.removeAll { $0.id == id }
    }

    var canCreate: Bool { backend.activePlantId != nil || !backend.plants.isEmpty }

    func makeDetailViewModel(for inspection: AdminInspection) -> AdminInspectionDetailViewModel {
        AdminInspectionDetailViewModel(backend: backend, inspection: inspection,
                                       onChange: { [weak self] in self?.apply($0) },
                                       onDelete: { [weak self] in self?.remove(id: $0) })
    }

    func makeFormViewModel() -> AdminInspectionFormViewModel {
        AdminInspectionFormViewModel(backend: backend, editing: nil)
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        inspections = []
        isLoading = false
        hasLoaded = false
        errorMessage = nil
        lastUpdated = nil
        loadedKey = nil
        searchText = ""
        clearFilters()
    }
}

/// I numeri dei riquadri in cima alla lista, sulle ispezioni visibili.
struct AdminInspectionCounts: Equatable {
    let total: Int
    let open: Int
    let overdue: Int
    let completed: Int

    init(_ inspections: [AdminInspection]) {
        total = inspections.count
        open = inspections.filter { !$0.isClosed }.count
        overdue = inspections.filter { $0.isOverdue() }.count
        completed = inspections.filter { $0.knownStatus == .completed }.count
    }
}

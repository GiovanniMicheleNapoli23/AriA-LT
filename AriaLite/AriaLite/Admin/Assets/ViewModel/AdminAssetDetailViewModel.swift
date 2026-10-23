//
//  AdminAssetDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un asset, come /assets/{tag} della web: scheda, disponibilità degli ultimi 30 giorni,
//  fermi macchina (registra, modifica, chiudi, elimina) e ordini di lavoro in sola lettura.
//  Ogni blocco si carica per conto suo: se uno fallisce (o il ruolo non lo vede) gli altri restano.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAssetDetailViewModel {
    let backend: AriaBackend
    let tag: String
    /// La riga della lista finché non arriva la scheda dal server, poi quella aggiornata.
    private(set) var asset: AdminAsset
    private(set) var assetError: String?

    private(set) var stats: AdminDowntimeStats?
    private(set) var statsError: String?
    private(set) var downtimes: [AdminDowntime] = []
    private(set) var downtimesError: String?
    private(set) var workOrders: [AdminAssetWorkOrder] = []
    private(set) var workOrdersError: String?

    private(set) var isLoading = false
    private(set) var hasLoaded = false
    /// Fermi con una richiesta in corso (chiusura, eliminazione).
    private(set) var busyDowntimeIds: Set<String> = []
    /// Errore di un'azione (chiudi, elimina): si mostra in un avviso.
    var actionError: String?
    /// Il fermo di cui si chiede conferma prima di eliminarlo.
    var downtimeToDelete: AdminDowntime?

    /// Per due `.alert` (errore e conferma): chiuderli azzera lo stato.
    var showsActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    var showsDeleteConfirmation: Bool {
        get { downtimeToDelete != nil }
        set { if !newValue { downtimeToDelete = nil } }
    }

    @ObservationIgnored private let onAssetChanged: (AdminAsset) -> Void

    init(backend: AriaBackend, asset: AdminAsset, onAssetChanged: @escaping (AdminAsset) -> Void = { _ in }) {
        self.backend = backend
        self.tag = asset.tag
        self.asset = asset
        self.onAssetChanged = onAssetChanged
    }

    // MARK: Scheda

    var plantName: String? {
        guard let id = asset.plantId else { return nil }
        return backend.plants.first { $0.id == id }?.name ?? id
    }

    var placeLine: String {
        [asset.typeLabel, asset.zone, plantName].compactMap { $0 }.joined(separator: " · ")
    }

    /// Le righe "Details": solo i campi con un valore.
    var fields: [AdminAssetField] {
        var rows: [AdminAssetField] = []
        func add(_ title: String, _ value: String?) {
            if let value, !value.isEmpty { rows.append(AdminAssetField(title: title, value: value)) }
        }
        add(String(localized: "Type"), asset.typeLabel)
        add(String(localized: "Status"), asset.statusLabel)
        add(String(localized: "Zone"), asset.zone)
        add(String(localized: "Plant"), plantName)
        add(String(localized: "Manufacturer"), asset.manufacturer)
        add(String(localized: "Model"), asset.model)
        add(String(localized: "Serial number"), asset.serialNumber)
        add(String(localized: "Power"), asset.powerKw.map { "\($0.formatted(.number.precision(.fractionLength(0...2)))) kW" })
        add(String(localized: "Drive tag"), asset.driveTag)
        add(String(localized: "Drive type"), asset.driveType)
        add(String(localized: "AI confidence"), asset.confidence.map { ($0 <= 1 ? $0 : $0 / 100).formatted(.percent.precision(.fractionLength(0))) })
        add(String(localized: "Created"), asset.createdAt?.formatted(date: .abbreviated, time: .shortened))
        add(String(localized: "Updated"), asset.updatedAt?.formatted(date: .abbreviated, time: .shortened))
        return rows
    }

    var canEdit: Bool { asset.serverId != nil }

    // MARK: Fermi

    /// Prima i fermi in corso, poi gli altri; ognuno dal più recente.
    var orderedDowntimes: [AdminDowntime] {
        sorted(downtimes.filter(\.isOpen)) + sorted(downtimes.filter { !$0.isOpen })
    }

    private func sorted(_ items: [AdminDowntime]) -> [AdminDowntime] {
        items.sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
    }

    /// Stabilimento del fermo: quello dell'asset, altrimenti quello attivo (il body lo richiede).
    var downtimePlantId: String? { asset.plantId ?? backend.activePlantId }
    var canLogDowntime: Bool { downtimePlantId != nil }

    func isBusy(_ downtime: AdminDowntime) -> Bool { busyDowntimeIds.contains(downtime.id) }

    func workOrderTitle(for id: String?) -> String? {
        guard let id else { return nil }
        return workOrders.first { $0.id == id }?.title
    }

    // MARK: Caricamento

    func load() async {
        isLoading = true
        defer { isLoading = false }
        // Le quattro richieste partono insieme; il client è Sendable, i valori si prendono prima.
        let api = backend.api
        let tag = tag
        let plantId = asset.plantId
        async let assetResult = Self.result { try await api.call(AdminAssetsAPI.asset(tag: tag)) }
        async let statsResult = Self.result { try await api.call(AdminAssetsAPI.downtimeStats(assetTag: tag)) }
        async let downtimeResult = Self.result { try await api.call(AdminAssetsAPI.downtimes(assetTag: tag, plantId: plantId)) }
        async let ordersResult = Self.result { try await api.call(AdminAssetsAPI.workOrders(assetTag: tag)) }

        switch await assetResult {
        case .success(let fresh):
            asset = fresh
            assetError = nil
            onAssetChanged(fresh)
        case .failure(let error):
            assetError = AdminAssetsFailure.message(for: error, backend: backend)
        }
        switch await statsResult {
        case .success(let json): stats = AdminDowntimeStats(json: json); statsError = nil
        case .failure(let error): statsError = AdminAssetsFailure.message(for: error, backend: backend)
        }
        switch await downtimeResult {
        case .success(let rows): downtimes = rows.items; downtimesError = nil
        case .failure(let error): downtimesError = AdminAssetsFailure.message(for: error, backend: backend)
        }
        switch await ordersResult {
        case .success(let rows): workOrders = rows.items; workOrdersError = nil
        case .failure(let error): workOrdersError = AdminAssetsFailure.message(for: error, backend: backend)
        }
        hasLoaded = true
    }

    nonisolated private static func result<T: Sendable>(_ work: @Sendable () async throws -> T) async -> Result<T, any Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    /// Le statistiche dopo un fermo registrato, modificato o eliminato.
    private func reloadStats() async {
        do {
            stats = AdminDowntimeStats(json: try await backend.api.call(AdminAssetsAPI.downtimeStats(assetTag: tag)))
            statsError = nil
        } catch {
            statsError = AdminAssetsFailure.message(for: error, backend: backend)
        }
    }

    // MARK: Azioni

    /// Dal form dell'asset: la scheda nuova vale anche per la lista.
    func assetSaved(_ saved: AdminAsset) {
        asset = saved
        onAssetChanged(saved)
    }

    /// Dal form di un fermo (nuovo o modificato).
    func downtimeSaved(_ saved: AdminDowntime) async {
        downtimes.removeAll { $0.id == saved.id }
        downtimes.append(saved)
        await reloadStats()
    }

    /// Chiude adesso un fermo in corso.
    func close(_ downtime: AdminDowntime) async {
        guard let id = downtime.serverId, !isBusy(downtime) else { return }
        var body = AdminPatchBody()
        body.value("ended_at", .string(AdminDowntime.wire(.now)), was: .null)
        busyDowntimeIds.insert(downtime.id)
        defer { busyDowntimeIds.remove(downtime.id) }
        do {
            let saved = try await backend.api.call(AdminAssetsAPI.updateDowntime(id: id, body))
            downtimes.removeAll { $0.id == downtime.id }
            downtimes.append(saved)
            await reloadStats()
        } catch {
            actionError = AdminAssetsFailure.message(for: error, backend: backend)
        }
    }

    /// Eliminazione confermata nell'alert.
    func delete(_ downtime: AdminDowntime) async {
        downtimeToDelete = nil
        guard let id = downtime.serverId, !isBusy(downtime) else { return }
        busyDowntimeIds.insert(downtime.id)
        defer { busyDowntimeIds.remove(downtime.id) }
        do {
            _ = try await backend.api.call(AdminAssetsAPI.deleteDowntime(id: id))
            downtimes.removeAll { $0.id == downtime.id }
            await reloadStats()
        } catch {
            actionError = AdminAssetsFailure.message(for: error, backend: backend)
        }
    }

    func makeAssetForm() -> AdminAssetFormViewModel {
        AdminAssetFormViewModel(backend: backend, editing: asset)
    }

    func makeDowntimeForm(editing downtime: AdminDowntime? = nil) -> AdminDowntimeFormViewModel {
        AdminDowntimeFormViewModel(backend: backend, assetTag: tag, plantId: downtimePlantId,
                                   workOrders: workOrders, editing: downtime)
    }
}

/// Una riga "titolo → valore" della scheda.
nonisolated struct AdminAssetField: Sendable, Hashable, Identifiable {
    let title: String
    let value: String
    var id: String { title }
}

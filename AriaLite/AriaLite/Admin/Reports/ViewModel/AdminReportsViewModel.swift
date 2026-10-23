//
//  AdminReportsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Reports, come la pagina /reports della web: filtro per stabilimento, panoramica, ordini di
//  lavoro, asset e widget salvati. Ogni parte ha il suo stato: se una fallisce le altre restano. Vive in
//  AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminReportsViewModel {
    let backend: AriaBackend

    /// Lo stabilimento scelto nel filtro; nil = tutti.
    var plantFilterId: String?

    private(set) var overview = AdminReportLoad<AdminReportOverview>()
    private(set) var workOrders = AdminReportLoad<AdminReportWorkOrders>()
    private(set) var assets = AdminReportLoad<AdminReportAssets>()
    private(set) var widgets = AdminReportLoad<[AdminCraftedWidget]>()
    private(set) var lastUpdated: Date?
    @ObservationIgnored private var loadedKey: String?
    @ObservationIgnored private var loadedCompanyId: String?

    // Eliminazione di un widget, sempre con conferma.
    var widgetToDelete: AdminCraftedWidget?
    var showsDeleteConfirmation = false
    var deletingId: String?
    var actionError: String?
    var showsActionError = false

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// Cambia quando va richiesto tutto di nuovo: azienda o stabilimento scelto.
    var loadKey: String { "\(backend.activeCompanyId ?? "-")|\(plantFilterId ?? "-")" }

    var plants: [AriaPlant] { backend.plants }
    var plantFilterLabel: String {
        plants.first { $0.id == plantFilterId }?.name ?? String(localized: "All plants")
    }

    var isLoading: Bool { overview.isLoading || workOrders.isLoading || assets.isLoading || widgets.isLoading }

    // MARK: Caricamento

    /// Richiede le quattro parti insieme, ognuna con il suo esito.
    func load() async {
        // Lo stabilimento scelto non c'è più (altra azienda): si torna a "tutti".
        if let id = plantFilterId, !plants.contains(where: { $0.id == id }) { plantFilterId = nil }
        let key = loadKey
        if key != loadedKey {
            // Altro filtro o altra azienda: i numeri vecchi non valgono, non si mostrano mentre arrivano i nuovi.
            overview.clear()
            workOrders.clear()
            assets.clear()
            if loadedCompanyId != backend.activeCompanyId { widgets.clear() }
            loadedKey = key
            loadedCompanyId = backend.activeCompanyId
        }
        let plantId = plantFilterId
        overview.isLoading = true
        workOrders.isLoading = true
        assets.isLoading = true
        widgets.isLoading = true
        async let overviewResult = outcome { [backend] in
            try await backend.api.call(AdminReportsAPI.overview(plantId: plantId))
        }
        async let workOrdersResult = outcome { [backend] in
            try await backend.api.call(AdminReportsAPI.workOrders(plantId: plantId))
        }
        async let assetsResult = outcome { [backend] in
            try await Self.assetsReport(backend: backend, plantId: plantId)
        }
        async let widgetsResult = outcome { [backend] in
            try await backend.api.call(AdminReportsAPI.widgets()).items
        }
        let results = await (overviewResult, workOrdersResult, assetsResult, widgetsResult)
        // Nel frattempo è cambiato il filtro: ci pensa il caricamento nuovo.
        guard key == loadKey else { return }
        overview.finish(results.0)
        workOrders.finish(results.1)
        assets.finish(results.2)
        widgets.finish(results.3)
        if overview.value != nil || workOrders.value != nil || assets.value != nil { lastUpdated = .now }
    }

    /// Il report degli asset; se le righe di top_failing non hanno il nome si prende da /v1/assets
    /// (un errore lì non rompe il report: restano i tag).
    private static func assetsReport(backend: AriaBackend, plantId: String?) async throws -> AdminReportAssets {
        let report = try await backend.api.call(AdminReportsAPI.assets(plantId: plantId))
        guard report.needsAssetNames,
              let names = try? await backend.api.call(AdminReportsAPI.assetNames()).items else { return report }
        return report.withNames(from: names)
    }

    /// Esegue una richiesta e ne racconta l'esito; una richiesta annullata non è un errore da mostrare.
    private func outcome<Value: Sendable>(
        _ request: @Sendable () async throws -> Value
    ) async -> AdminReportOutcome<Value> {
        do {
            let value = try await request()
            return Task.isCancelled ? .cancelled : .value(value)
        } catch {
            guard let message = AdminCraftedFailure.message(for: error, backend: backend) else { return .cancelled }
            return .failure(message)
        }
    }

    /// Un widget eliminato sul server: esce dalla lista senza ricaricare.
    func removeWidget(id: String) {
        widgets.update { $0.removeAll { $0.serverId == id } }
    }

    // MARK: Uscita

    /// All'uscita dall'account: niente dati dell'azienda precedente.
    func reset() {
        plantFilterId = nil
        overview.clear()
        workOrders.clear()
        assets.clear()
        widgets.clear()
        lastUpdated = nil
        loadedKey = nil
        loadedCompanyId = nil
        widgetToDelete = nil
        showsDeleteConfirmation = false
        deletingId = nil
        actionError = nil
        showsActionError = false
    }
}

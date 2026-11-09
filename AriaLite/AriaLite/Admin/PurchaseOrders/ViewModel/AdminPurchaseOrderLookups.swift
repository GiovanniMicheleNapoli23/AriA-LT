//
//  AdminPurchaseOrderLookups.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I fornitori per i selettori e i nomi degli ordini (GET /v1/vendors), condivisi da lista, modulo e dettaglio.
//  Si scaricano alla prima apertura e si riaggiornano ogni volta che si tira per aggiornare o si apre un modulo
//  (al massimo una volta al minuto); se il caricamento fallisce l'elenco resta vuoto e niente si blocca:
//  gli ordini mostrano solo i dati che hanno.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminPurchaseOrderLookups {
    let backend: AriaBackend
    private(set) var vendors: [AdminSparePartVendor] = []
    private(set) var isLoading = false
    /// L'azienda per cui sono stati scaricati: un'altra azienda li riscarica.
    private var loadedCompanyId: String??
    private var lastLoadedAt: Date?
    /// Per quanto tempo l'elenco si considera aggiornato (secondi).
    private static let freshnessWindow: TimeInterval = 60

    init(backend: AriaBackend) {
        self.backend = backend
    }

    var hasLoaded: Bool { loadedCompanyId == .some(backend.activeCompanyId) }

    /// In ordine alfabetico, per i selettori.
    var sortedVendors: [AdminSparePartVendor] {
        vendors.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    /// Riscarica i fornitori (ne possono nascere o cambiare nome dalla sezione Fornitori); se fallisce
    /// resta l'elenco di prima. Non parte se un caricamento è già in corso.
    func refresh() async {
        guard !isLoading else { return }
        let company = backend.activeCompanyId
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await AdminSparePartsAPI(api: backend.api).vendors()
            // Se l'azienda è cambiata mentre si scaricava, l'elenco non vale più.
            guard company == backend.activeCompanyId else { return }
            vendors = loaded
            loadedCompanyId = .some(company)
            lastLoadedAt = .now
        } catch {
            // Tollerante: senza fornitori gli ordini si mostrano lo stesso, senza il loro nome.
            // `from` gestisce comunque una sessione scaduta.
            _ = AdminPurchaseOrdersFailure.from(error, action: .read, backend: backend)
        }
    }

    /// Riscarica solo se l'elenco è vecchio (oltre `freshnessWindow`) o non c'è: costa poco aprire un modulo.
    func refreshIfStale() async {
        if hasLoaded, let lastLoadedAt, Date.now.timeIntervalSince(lastLoadedAt) < Self.freshnessWindow { return }
        await refresh()
    }

    func vendorName(for id: String?) -> String? {
        guard let id else { return nil }
        return vendors.first { $0.id == id }?.name
    }

    func reset() {
        vendors = []
        loadedCompanyId = nil
        lastLoadedAt = nil
    }
}

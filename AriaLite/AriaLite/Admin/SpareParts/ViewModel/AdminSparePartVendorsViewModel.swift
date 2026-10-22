//
//  AdminSparePartVendorsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I fornitori dell'azienda, scaricati una volta e condivisi da lista, dettaglio e modulo:
//  servono per il nome del fornitore di un ricambio e per la scelta nel modulo.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminSparePartVendorsViewModel {
    private let backend: AriaBackend

    private(set) var vendors: [AdminSparePartVendor] = []
    private(set) var isLoading = false
    private(set) var failure: AdminSparePartsFailure?
    /// L'azienda per cui sono stati scaricati: un'altra azienda li riscarica.
    private var loadedCompanyId: String??

    init(backend: AriaBackend) {
        self.backend = backend
    }

    var hasLoaded: Bool { loadedCompanyId == .some(backend.activeCompanyId) }

    /// In ordine alfabetico, per la scelta nel modulo.
    var sorted: [AdminSparePartVendor] {
        vendors.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func name(for id: String?) -> String? {
        guard let id else { return nil }
        return vendors.first { $0.id == id }?.displayName
    }

    func loadIfNeeded() async {
        guard !hasLoaded, !isLoading else { return }
        await load()
    }

    func load() async {
        let company = backend.activeCompanyId
        isLoading = true
        defer { isLoading = false }
        do {
            vendors = try await AdminSparePartsAPI(api: backend.api).vendors()
            loadedCompanyId = .some(company)
            failure = nil
        } catch {
            if let failure = AdminSparePartsFailure.from(error, action: .read, backend: backend) { self.failure = failure }
        }
    }

    func reset() {
        vendors = []
        failure = nil
        loadedCompanyId = nil
    }
}

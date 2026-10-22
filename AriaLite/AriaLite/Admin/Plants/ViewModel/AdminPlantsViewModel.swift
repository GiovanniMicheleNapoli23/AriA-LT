//
//  AdminPlantsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Plants, come la pagina /plants della web. Vive in AppViewModel: i dati restano fra un
//  cambio di sezione e l'altro. Ogni modifica riscarica anche l'elenco condiviso (`backend.plants`),
//  che usano la chat e le altre sezioni.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminPlantsViewModel {
    let backend: AriaBackend

    /// Cosa mostrare al posto della lista.
    enum Placeholder: Equatable {
        case loading
        case failed(AdminPlantsFailure)
        case empty
        case noResults(String)
    }

    // MARK: - State

    private(set) var plants: [AdminPlant] = []
    /// Azienda per cui l'elenco è stato scaricato.
    private(set) var loadedKey: String?
    private(set) var isLoading = false
    private(set) var failure: AdminPlantsFailure?
    private(set) var lastUpdated: Date?

    var query = ""
    /// Il modulo di creazione aperto (sheet).
    var newPlantForm: AdminPlantFormViewModel?

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        plants = []
        loadedKey = nil
        isLoading = false
        failure = nil
        lastUpdated = nil
        query = ""
        newPlantForm = nil
    }

    // MARK: - Caricamento

    /// Cambia quando va riscaricato l'elenco: l'azienda.
    var loadKey: String { backend.activeCompanyId ?? "-" }

    func loadIfNeeded() async {
        if loadedKey != loadKey { await refresh() }
    }

    func refresh() async {
        let key = loadKey
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await AdminPlantsAPI(api: backend.api).list()
            // Nel frattempo è cambiata l'azienda: questo elenco non è più quello giusto.
            guard key == loadKey else { return }
            plants = fresh
            loadedKey = key
            failure = nil
            lastUpdated = .now
        } catch {
            if let failure = AdminPlantsFailure.from(error, action: .read, backend: backend) { self.failure = failure }
        }
    }

    // MARK: - Lista

    /// Gli stabilimenti che corrispondono alla ricerca, in ordine alfabetico.
    var visiblePlants: [AdminPlant] {
        plants.filter(matches).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func matches(_ plant: AdminPlant) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        return [plant.name, plant.code, plant.location].contains { $0?.localizedStandardContains(q) == true }
    }

    /// Lo stabilimento attivo nell'app (quello della chat), se è in elenco.
    func isActive(_ plant: AdminPlant) -> Bool { backend.activePlantId == plant.id }

    var placeholder: Placeholder? {
        if loadedKey != loadKey {
            if let failure { return .failed(failure) }
            return .loading
        }
        if plants.isEmpty { return .empty }
        guard visiblePlants.isEmpty else { return nil }
        return .noResults(query.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito.
    var refreshFailed: Bool { loadedKey == loadKey && failure != nil }

    // MARK: - Modifiche

    func startCreating() {
        newPlantForm = AdminPlantFormViewModel(mode: .create, owner: self)
    }

    /// Uno stabilimento creato o modificato: si aggiorna nell'elenco e nell'elenco condiviso dell'app.
    func didSave(_ plant: AdminPlant) async {
        if let index = plants.firstIndex(where: { $0.id == plant.id }) {
            plants[index] = plant
        } else {
            plants.append(plant)
        }
        await reloadShared()
    }

    /// Eliminato: esce dall'elenco e dall'elenco condiviso.
    func didDelete(id: String) async {
        plants.removeAll { $0.id == id }
        await reloadShared()
    }

    /// Il server è la fonte: si riscarica l'elenco condiviso. Un errore qui non blocca la modifica già salvata.
    private func reloadShared() async {
        try? await backend.reloadPlants()
    }
}

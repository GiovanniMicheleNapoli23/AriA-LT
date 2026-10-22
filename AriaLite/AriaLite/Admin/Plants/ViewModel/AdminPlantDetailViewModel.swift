//
//  AdminPlantDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di uno stabilimento: campi, date, modifica e eliminazione (con conferma).
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminPlantDetailViewModel {
    let owner: AdminPlantsViewModel

    // MARK: - State

    private(set) var plant: AdminPlant
    private(set) var isDeleting = false
    /// Il modulo di modifica aperto (sheet).
    var editForm: AdminPlantFormViewModel?
    /// "Eliminare questo stabilimento?" (conferma).
    var showsDeleteConfirmation = false
    /// Errore dell'eliminazione (alert), con il messaggio del server.
    var deleteError: String?
    var isShowingDeleteError: Bool {
        get { deleteError != nil }
        set { if !newValue { deleteError = nil } }
    }

    init(plant: AdminPlant, owner: AdminPlantsViewModel) {
        self.plant = plant
        self.owner = owner
    }

    // MARK: - Scheda

    var isActive: Bool { owner.isActive(plant) }

    /// Codice e ubicazione, come righe etichetta-valore. Le righe vuote non si mostrano.
    var detailRows: [(label: String, value: String)] {
        var rows: [(label: String, value: String)] = []
        if let location = plant.location { rows.append((String(localized: "Location"), location)) }
        return rows
    }

    /// Creato e aggiornato, come righe etichetta-valore.
    var dateRows: [(label: String, value: String)] {
        [(String(localized: "Created"), plant.createdAt), (String(localized: "Updated"), plant.updatedAt)]
            .compactMap { label, date in
                date.map { (label, $0.formatted(date: .abbreviated, time: .shortened)) }
            }
    }

    // MARK: - Azioni

    func startEditing() {
        editForm = AdminPlantFormViewModel(mode: .edit(plant), owner: owner) { [weak self] saved in
            self?.plant = saved
        }
    }

    /// `true` se eliminato: la schermata si chiude. Un 404 vuol dire che non c'era già più.
    func delete() async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await AdminPlantsAPI(api: owner.backend.api).delete(id: plant.id)
        } catch {
            guard let failure = AdminPlantsFailure.from(error, action: .write, backend: owner.backend) else {
                return false
            }
            guard failure.isNotFound else {
                deleteError = failure.message
                return false
            }
        }
        await owner.didDelete(id: plant.id)
        return true
    }
}

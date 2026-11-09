//
//  AdminPlantFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo di creazione e modifica di uno stabilimento: validazione, salvataggio, errore del server.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminPlantFormViewModel: Identifiable {
    enum Mode {
        case create
        case edit(AdminPlant)
    }

    let mode: Mode
    let owner: AdminPlantsViewModel
    /// Lo stabilimento salvato, per chi ha aperto il modulo (il dettaglio).
    private let onSaved: ((AdminPlant) -> Void)?

    // MARK: - Campi

    var name = ""
    var code = ""
    var location = ""
    var description = ""

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(mode: Mode, owner: AdminPlantsViewModel, onSaved: ((AdminPlant) -> Void)? = nil) {
        self.mode = mode
        self.owner = owner
        self.onSaved = onSaved
        if case .edit(let plant) = mode {
            name = plant.name
            code = plant.code
            location = plant.location ?? ""
            description = plant.description ?? ""
        }
    }

    // MARK: - Presentazione

    var isEditing: Bool { if case .edit = mode { true } else { false } }

    var title: String { isEditing ? String(localized: "Edit plant") : String(localized: "New plant") }

    /// Nome e codice sono obbligatori: senza, Save resta spento.
    var canSave: Bool { !isSaving && !trimmed(name).isEmpty && !trimmed(code).isEmpty }

    /// Qualcosa è cambiato: chiudere con un trascinamento perderebbe le modifiche.
    var hasChanges: Bool {
        switch mode {
        case .create:
            [name, code, location, description].contains { !trimmed($0).isEmpty }
        case .edit(let plant):
            trimmed(name) != plant.name || trimmed(code) != plant.code
                || optional(location) != plant.location || optional(description) != plant.description
        }
    }

    // MARK: - Lettura dei campi

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func optional(_ text: String) -> String? {
        let value = trimmed(text)
        return value.isEmpty ? nil : value
    }

    // MARK: - Salvataggio

    /// `true` se salvato: il modulo si chiude. In caso di errore resta aperto con il messaggio del server.
    func save() async -> Bool {
        guard canSave else { return false }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        let api = AdminPlantsAPI(api: owner.backend.api)
        do {
            let saved: AdminPlant
            switch mode {
            case .create:
                saved = try await api.create(AdminPlantCreate(
                    name: trimmed(name), code: trimmed(code),
                    description: optional(description), location: optional(location)))
            case .edit(let plant):
                saved = try await api.update(id: plant.id, AdminPlantUpdate(
                    name: trimmed(name), code: trimmed(code),
                    description: optional(description), location: optional(location)))
            }
            await owner.didSave(saved)
            onSaved?(saved)
            return true
        } catch {
            if let failure = AdminPlantsFailure.from(error, action: .write, backend: owner.backend) {
                errorMessage = failure.message
            }
            return false
        }
    }
}

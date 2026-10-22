//
//  AdminMemoryFactFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Scrive un fatto a mano (POST: entra già approvato) o ne modifica testo, contesto e categoria (PUT:
//  lo stato non cambia). Parte sempre dal testo originale, mai dalla traduzione mostrata in lista.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMemoryFactFormViewModel: Identifiable {
    let backend: AriaBackend
    /// `nil`: fatto nuovo.
    let original: AdminMemoryFact?

    var content: String
    var context: String
    var category: String
    var plantId: String?

    private(set) var isSaving = false
    var errorMessage: String?

    nonisolated let id = UUID()

    init(backend: AriaBackend, editing fact: AdminMemoryFact?) {
        self.backend = backend
        original = fact
        content = fact?.content ?? ""
        context = fact?.context ?? ""
        category = fact?.category ?? ""
        plantId = fact?.plantId ?? backend.activePlantId ?? backend.plants.first?.id
    }

    var isEditing: Bool { original != nil }
    var title: String { isEditing ? String(localized: "Edit fact") : String(localized: "New fact") }
    var plants: [AriaPlant] { backend.plants }

    /// Il fatto approvato si ricalcola per la ricerca: lo si dice sotto il testo.
    var contentFooter: String? {
        if !isEditing { return String(localized: "Facts you write are trusted: Aria starts using them right away.") }
        if original?.knownStatus == .approved { return String(localized: "Aria will use the new wording from now on.") }
        return nil
    }

    // MARK: Validazione

    private func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Il primo problema da correggere, mostrato sotto il form; `nil` se si può salvare.
    var validationMessage: String? {
        let text = trimmed(content)
        if text.isEmpty { return String(localized: "Write the fact.") }
        if text.count > AdminMemoryFactCreate.maxContent {
            return String(localized: "The fact is too long: keep it under \(AdminMemoryFactCreate.maxContent) characters.")
        }
        if trimmed(context).count > AdminMemoryFactCreate.maxContext || trimmed(category).count > AdminMemoryFactCreate.maxContext {
            return String(localized: "Context and category can be at most \(AdminMemoryFactCreate.maxContext) characters.")
        }
        if !isEditing, plantId == nil { return String(localized: "Select a plant.") }
        return nil
    }

    /// Solo i campi cambiati; contesto e categoria vuoti si tolgono (stringa vuota per il server).
    private var changes: AdminMemoryFactUpdate {
        var body = AdminMemoryFactUpdate()
        guard let original else { return body }
        if trimmed(content) != original.content { body.content = trimmed(content) }
        if trimmed(context) != (original.context ?? "") { body.context = trimmed(context) }
        if trimmed(category) != (original.category ?? "") { body.category = trimmed(category) }
        return body
    }

    var canSave: Bool {
        guard validationMessage == nil, !isSaving else { return false }
        return !isEditing || !changes.isEmpty
    }

    // MARK: Salvataggio

    /// Il fatto salvato, o `nil` se il server ha rifiutato (il motivo è in `errorMessage`).
    func save() async -> AdminMemoryFact? {
        guard canSave, let companyId = backend.activeCompanyId else { return nil }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            if let original {
                return try await backend.api.call(AdminLearnedKnowledgeAPI.update(companyId: companyId, factId: original.id, changes))
            }
            guard let plantId else { return nil }
            func optional(_ value: String) -> String? { trimmed(value).isEmpty ? nil : trimmed(value) }
            let body = AdminMemoryFactCreate(content: trimmed(content), context: optional(context),
                                             category: optional(category), plantId: plantId)
            return try await backend.api.call(AdminLearnedKnowledgeAPI.create(companyId: companyId, body))
        } catch {
            errorMessage = AdminLearnedKnowledgeFailure.message(for: error, backend: backend)
            return nil
        }
    }
}

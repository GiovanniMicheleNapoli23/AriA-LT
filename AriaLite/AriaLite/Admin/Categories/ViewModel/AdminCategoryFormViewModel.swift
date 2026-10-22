//
//  AdminCategoryFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo di una categoria: nuova (POST, nello stabilimento scelto) o modifica (PATCH con i soli campi
//  cambiati; un campo svuotato si manda come null). Lo stabilimento "tutti" esiste solo in modifica: la
//  creazione richiede `plant_id` nello schema.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class AdminCategoryFormViewModel: Identifiable {
    enum Mode {
        case create
        case edit(AdminCategory)
    }

    let mode: Mode
    let owner: AdminCategoriesViewModel
    /// Il colore di partenza in #RRGGBB (`nil` se non ce n'era): si manda solo se cambia.
    private let initialColorHex: String?

    // MARK: - Campi

    var name = ""
    var entityType = ""
    var description = ""
    var icon = ""
    var hasColor = false
    var color: Color = .blue
    /// `nil` = tutti gli stabilimenti (solo in modifica).
    var plantId: String?

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(mode: Mode, owner: AdminCategoriesViewModel) {
        self.mode = mode
        self.owner = owner
        var startColor: String?
        switch mode {
        case .create:
            plantId = owner.backend.activePlantId
        case .edit(let category):
            name = category.name
            entityType = category.entityType
            description = category.description ?? ""
            icon = category.icon ?? ""
            if let parsed = AdminCategoryColor.color(from: category.color) {
                hasColor = true
                color = parsed
                startColor = AdminCategoryColor.hex(from: parsed)
            }
            plantId = category.plantId
        }
        initialColorHex = startColor
    }

    // MARK: - Presentazione

    var isEditing: Bool { if case .edit = mode { true } else { false } }

    var title: String { isEditing ? String(localized: "Edit category") : String(localized: "New category") }

    /// Tipi già usati, per suggerirli (il campo resta libero).
    var entityTypeSuggestions: [String] { owner.entityTypes }

    var plants: [AriaPlant] { owner.plants }

    /// Salvare richiede un nome, un tipo e (in creazione) uno stabilimento.
    var canSave: Bool {
        !isSaving && !trimmed(name).isEmpty && !trimmed(entityType).isEmpty && (isEditing || plantId != nil)
    }

    var iconIsValid: Bool { AdminCategoryIcon.isValid(icon) }

    /// Qualcosa è cambiato: chiudere con un trascinamento perderebbe le modifiche.
    var hasChanges: Bool {
        switch mode {
        case .create: !trimmed(name).isEmpty || !trimmed(entityType).isEmpty || !trimmed(description).isEmpty
        case .edit(let category): !patch(from: category).isEmpty
        }
    }

    /// Nome dello stabilimento scelto, o "tutti".
    func plantLabel(_ id: String?) -> String {
        guard let id else { return String(localized: "All plants") }
        return plants.first { $0.id == id }?.name ?? String(localized: "Unknown plant")
    }

    // MARK: - Lettura dei campi

    private struct InvalidField: Error {
        let message: String
    }

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func optional(_ text: String) -> String? {
        let value = trimmed(text)
        return value.isEmpty ? nil : value
    }

    /// Il colore da mandare: `nil` se spento, altrimenti #RRGGBB.
    private var colorValue: String? { hasColor ? AdminCategoryColor.hex(from: color) : nil }

    private func validate() throws {
        guard !trimmed(name).isEmpty else { throw InvalidField(message: String(localized: "Name is required.")) }
        guard !trimmed(entityType).isEmpty else {
            throw InvalidField(message: String(localized: "Entity type is required."))
        }
        guard iconIsValid else {
            throw InvalidField(
                message: String(localized: "This isn't a valid symbol name. Leave it empty for the default icon.")
            )
        }
        if !isEditing, plantId == nil {
            throw InvalidField(message: String(localized: "Choose a plant for the new category."))
        }
    }

    // MARK: - Body

    private func createBody(plantId: String) -> AdminCategoryCreate {
        AdminCategoryCreate(
            name: trimmed(name), entityType: trimmed(entityType), description: optional(description),
            color: colorValue, icon: optional(icon), plantId: plantId
        )
    }

    /// Solo i campi diversi dalla categoria di partenza.
    private func patch(from category: AdminCategory) -> AdminCategoryUpdate {
        var update = AdminCategoryUpdate()
        if trimmed(name) != category.name { update.fields[.name] = .string(trimmed(name)) }
        if trimmed(entityType) != category.entityType { update.fields[.entityType] = .string(trimmed(entityType)) }
        if optional(description) != category.description {
            update.fields[.description] = optional(description).map(AriaJSON.string) ?? .null
        }
        if colorValue != initialColorHex {
            update.fields[.color] = colorValue.map(AriaJSON.string) ?? .null
        }
        if optional(icon) != category.icon {
            update.fields[.icon] = optional(icon).map(AriaJSON.string) ?? .null
        }
        if plantId != category.plantId {
            update.fields[.plantId] = plantId.map(AriaJSON.string) ?? .null
        }
        return update
    }

    // MARK: - Salvataggio

    /// `true` se salvato (o niente da salvare): il modulo si può chiudere.
    func save() async -> Bool {
        guard !isSaving else { return false }
        errorMessage = nil
        do { try validate() } catch {
            errorMessage = (error as? InvalidField)?.message ?? error.localizedDescription
            return false
        }
        let api = AdminCategoriesAPI(api: owner.backend.api)
        isSaving = true
        defer { isSaving = false }
        do {
            switch mode {
            case .create:
                guard let plantId else { return false }
                let created = try await api.create(createBody(plantId: plantId))
                owner.didCreate(created)
            case .edit(let category):
                let update = patch(from: category)
                guard !update.isEmpty else { return true }
                let saved = try await api.update(id: category.id, update)
                owner.didSave(saved)
            }
            return true
        } catch {
            if let failure = AdminCategoriesFailure.from(error, action: .write, backend: owner.backend) {
                errorMessage = failure.message
            }
            return false
        }
    }
}

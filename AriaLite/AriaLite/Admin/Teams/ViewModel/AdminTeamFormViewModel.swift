//
//  AdminTeamFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo di una squadra: nuova (POST /v1/teams, nello stabilimento attivo se c'è) o modifica (PATCH con i soli
//  campi cambiati; un campo svuotato si manda come null).
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminTeamFormViewModel: Identifiable {
    enum Mode {
        case create
        case edit(AdminTeam)
    }

    let mode: Mode
    let owner: AdminTeamsViewModel
    /// La squadra salvata, per chi ha aperto il modulo (il dettaglio).
    private let onSaved: ((AdminTeam) -> Void)?

    var name = ""
    var description = ""
    /// Lo stabilimento scelto (`nil` = nessuno).
    var plantId: String?

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(mode: Mode, owner: AdminTeamsViewModel, onSaved: ((AdminTeam) -> Void)? = nil) {
        self.mode = mode
        self.owner = owner
        self.onSaved = onSaved
        switch mode {
        case .create:
            plantId = owner.backend.activePlantId
        case .edit(let team):
            name = team.name
            description = team.description ?? ""
            plantId = team.plantId
        }
    }

    // MARK: - Presentazione

    var isEditing: Bool { if case .edit = mode { true } else { false } }

    var title: String { isEditing ? String(localized: "Edit team") : String(localized: "New team") }

    var plants: [AriaPlant] { owner.backend.plants }

    var canSave: Bool { !isSaving && !trimmed(name).isEmpty }

    /// Qualcosa è cambiato: chiudere con un trascinamento perderebbe le modifiche.
    var hasChanges: Bool {
        switch mode {
        case .create: !trimmed(name).isEmpty || !trimmed(description).isEmpty
        case .edit(let team): !patch(from: team).isEmpty
        }
    }

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func optional(_ text: String) -> String? {
        let value = trimmed(text)
        return value.isEmpty ? nil : value
    }

    // MARK: - Body

    /// Solo i campi diversi dalla squadra di partenza.
    private func patch(from team: AdminTeam) -> AdminTeamUpdate {
        var update = AdminTeamUpdate()
        if trimmed(name) != team.name { update.fields[.name] = .string(trimmed(name)) }
        if optional(description) != team.trimmedDescription {
            update.fields[.description] = optional(description).map(AriaJSON.string) ?? .null
        }
        if plantId != team.plantId { update.fields[.plantId] = plantId.map(AriaJSON.string) ?? .null }
        return update
    }

    // MARK: - Salvataggio

    /// `true` se salvato (o niente da salvare): il modulo si può chiudere.
    func save() async -> Bool {
        guard !isSaving else { return false }
        errorMessage = nil
        guard !trimmed(name).isEmpty else {
            errorMessage = String(localized: "Name is required.")
            return false
        }
        let api = owner.api
        isSaving = true
        defer { isSaving = false }
        do {
            switch mode {
            case .create:
                let created = try await api.create(
                    AdminTeamCreate(name: trimmed(name), description: optional(description), plantId: plantId))
                owner.didCreate(created)
                onSaved?(created)
                await owner.refreshWorkloads(for: [created.id])
            case .edit(let team):
                let update = patch(from: team)
                guard !update.isEmpty else { return true }
                let saved = try await api.update(id: team.id, update)
                owner.didSave(saved)
                onSaved?(saved)
            }
            return true
        } catch {
            if let failure = AdminTeamsFailure.from(error, action: .write, backend: owner.backend) {
                errorMessage = failure.message
            }
            return false
        }
    }
}

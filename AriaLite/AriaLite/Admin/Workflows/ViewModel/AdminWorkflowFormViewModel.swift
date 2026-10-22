//
//  AdminWorkflowFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Crea un flusso (nome, descrizione e, a scelta, il grafo di un modello) o ne cambia nome e descrizione
//  (PATCH con la `revision` letta). Il grafo non si modifica da telefono.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkflowFormViewModel: Identifiable {
    let backend: AriaBackend
    /// `nil`: flusso nuovo.
    let original: AdminWorkflow?
    /// Rilegge il flusso del dettaglio dopo un conflitto di revisione.
    private let reload: (@MainActor () async -> Void)?

    var name: String
    var description: String
    /// Il modello scelto per un flusso nuovo; `nil`: parte vuoto.
    var template: AdminWorkflowTemplate?

    private(set) var templates: [AdminWorkflowTemplate] = []
    private(set) var isLoadingTemplates = false
    private(set) var templatesLoaded = false
    private(set) var isSaving = false
    var errorMessage: String?

    nonisolated let id = UUID()

    init(backend: AriaBackend, editing flow: AdminWorkflow?, reload: (@MainActor () async -> Void)?) {
        self.backend = backend
        original = flow
        self.reload = reload
        name = flow?.name ?? ""
        description = flow?.description ?? ""
    }

    var isEditing: Bool { original != nil }
    var title: String { isEditing ? String(localized: "Edit flow") : String(localized: "New flow") }

    // MARK: Modelli

    /// Solo per un flusso nuovo. Se la rotta non risponde il flusso si crea comunque vuoto, senza errori.
    func loadTemplates() async {
        guard !isEditing, !templatesLoaded, !isLoadingTemplates else { return }
        isLoadingTemplates = true
        defer { isLoadingTemplates = false }
        if let list = try? await backend.api.call(AdminWorkflowsAPI.templates()) { templates = list.templates }
        templatesLoaded = true
    }

    // MARK: Validazione

    private func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Il primo problema da correggere, mostrato sotto il form; `nil` se si può salvare.
    var validationMessage: String? {
        if trimmed(name).isEmpty { return String(localized: "Give the flow a name.") }
        if trimmed(name).count > AdminWorkflowCreate.maxName {
            return String(localized: "The name is too long: keep it under \(AdminWorkflowCreate.maxName) characters.")
        }
        if trimmed(description).count > AdminWorkflowCreate.maxDescription {
            return String(localized: """
                The description is too long: \
                keep it under \(AdminWorkflowCreate.maxDescription) characters.
                """)
        }
        return nil
    }

    /// Solo i campi cambiati; la descrizione svuotata si manda vuota.
    private var changes: AdminWorkflowMetadataUpdate {
        var body = AdminWorkflowMetadataUpdate(revision: original?.revision ?? 0)
        guard let original else { return body }
        if trimmed(name) != original.name { body.name = trimmed(name) }
        if trimmed(description) != (original.description ?? "") { body.description = trimmed(description) }
        return body
    }

    var canSave: Bool {
        guard validationMessage == nil, !isSaving else { return false }
        return !isEditing || !changes.isEmpty
    }

    // MARK: Salvataggio

    /// Il flusso salvato, o `nil` se il server ha rifiutato (il motivo è in `errorMessage`).
    func save() async -> AdminWorkflow? {
        guard canSave, let companyId = backend.activeCompanyId else { return nil }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            if let original {
                return try await backend.api.call(
                    AdminWorkflowsAPI.update(companyId: companyId, flowId: original.id, changes))
            }
            let body = try await newFlowBody()
            return try await backend.api.call(AdminWorkflowsAPI.create(companyId: companyId, body))
        } catch let failure as AdminWorkflowFormError {
            errorMessage = failure.message
            return nil
        } catch {
            errorMessage = AdminWorkflowFailure.message(for: error, backend: backend)
            if AdminWorkflowFailure.isConflict(error) { await reload?() }
            return nil
        }
    }

    /// Il corpo del POST: se c'è un modello se ne scarica il grafo (uno senza nodi non si può usare).
    private func newFlowBody() async throws -> AdminWorkflowCreate {
        let text = trimmed(description)
        var body = AdminWorkflowCreate(name: trimmed(name), description: text.isEmpty ? nil : text)
        if let template {
            let fetched = try await backend.api.call(AdminWorkflowsAPI.templateGraph(name: template.name))
            guard !fetched.graph.nodes.isEmpty else { throw AdminWorkflowFormError.emptyTemplate }
            body.graph = fetched.graph
        }
        return body
    }
}

private enum AdminWorkflowFormError: Error {
    case emptyTemplate

    var message: String {
        String(localized: """
            This template has no steps the phone can read. \
            Pick another one, or start from an empty flow.
            """)
    }
}

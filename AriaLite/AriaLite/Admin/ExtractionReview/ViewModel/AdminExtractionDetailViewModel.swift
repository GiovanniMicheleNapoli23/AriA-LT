//
//  AdminExtractionDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un elemento da rivedere: correzione dei campi principali (PATCH dei soli cambiati),
//  proposta dell'AI da applicare ai campi, approva o rifiuta. L'AI è in +AI.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminExtractionDetailViewModel {
    let backend: AriaBackend
    private(set) var item: AdminExtractionItem
    /// Il testo di ogni campo nell'editor, per chiave.
    var drafts: [String: String] = [:]
    private(set) var isSaving = false
    private(set) var isDeciding = false
    /// Errore di salvataggio o di decisione: si mostra in un avviso.
    var actionError: String?
    /// Rilettura dal server fallita: una riga discreta, il resto funziona sulla copia della lista.
    private(set) var refreshError: String?

    // Stato dell'AI (vedi +AI).
    var customPrompt = ""
    var aiAction: AdminExtractionAIAction?
    var proposal: AdminExtractionAIProposal?
    var aiError: String?

    @ObservationIgnored private let onSaved: (AdminExtractionItem) -> Void
    @ObservationIgnored private let onDecision: (AdminExtractionItem, String) async -> Bool

    var showsActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    init(backend: AriaBackend, item: AdminExtractionItem,
         onSaved: @escaping (AdminExtractionItem) -> Void,
         onDecision: @escaping (AdminExtractionItem, String) async -> Bool) {
        self.backend = backend
        self.item = item
        self.onSaved = onSaved
        self.onDecision = onDecision
        resetDrafts()
    }

    var client: AdminExtractionReviewClient { AdminExtractionReviewClient(api: backend.api) }

    // MARK: Campi

    var fields: [AdminExtractionField] { item.editableFields }

    func draft(_ field: AdminExtractionField) -> String { drafts[field.key] ?? field.value }

    func setDraft(_ text: String, for field: AdminExtractionField) { drafts[field.key] = text }

    func isChanged(_ field: AdminExtractionField) -> Bool { !field.isUnchanged(draft(field)) }

    /// Un campo cambiato ma non valido (numero illeggibile, obbligatorio vuoto).
    func isInvalid(_ field: AdminExtractionField) -> Bool { isChanged(field) && field.wireValue(for: draft(field)) == nil }

    var isDirty: Bool { fields.contains(where: isChanged) }
    var hasInvalidFields: Bool { fields.contains(where: isInvalid) }
    var canEdit: Bool { item.canEdit }
    var canSave: Bool { canEdit && isDirty && !hasInvalidFields && !isSaving && !isDeciding }
    var canDecide: Bool { canEdit && !hasInvalidFields && !isSaving && !isDeciding }

    func resetDrafts() {
        drafts = Dictionary(uniqueKeysWithValues: fields.map { ($0.key, $0.value) })
    }

    var statusLabel: String? { item.status.map(AdminAssetStatus.label(for:)) }

    var confidenceText: String? {
        item.confidence.map { $0.formatted(.percent.precision(.fractionLength(0))) }
    }

    // MARK: Caricamento

    /// La versione del server all'apertura; non tocca i campi già modificati.
    func refresh() async {
        guard item.canEdit else { return }
        do {
            let fresh = try await client.refreshed(item)
            refreshError = nil
            guard !isDirty else { return }
            item = fresh
            resetDrafts()
            onSaved(fresh)
        } catch {
            refreshError = AdminExtractionReviewFailure.message(for: error, backend: backend)
        }
    }

    // MARK: Salvataggio

    /// PATCH dei soli campi cambiati. `true` se è andata o non c'era niente da salvare.
    @discardableResult
    func save() async -> Bool {
        guard isDirty else { return true }
        guard canSave else { return false }
        var body = AdminPatchBody()
        for field in fields where isChanged(field) {
            guard let value = field.wireValue(for: draft(field)) else { return false }
            body.adminExtractionSet(field.key, value)
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let saved = try await client.update(item, body)
            item = saved
            resetDrafts()
            onSaved(saved)
            return true
        } catch {
            actionError = AdminExtractionReviewFailure.message(for: error, backend: backend)
            return false
        }
    }

    // MARK: Decisione

    /// Salva le correzioni ancora aperte, poi approva o rifiuta. `true` se il dettaglio si può chiudere.
    func decide(_ status: String) async -> Bool {
        guard canDecide else { return false }
        if status == AdminExtractionStatus.approved, isDirty, !(await save()) { return false }
        isDeciding = true
        defer { isDeciding = false }
        return await onDecision(item, status)
    }
}

extension AdminPatchBody {
    /// Un valore da mandare comunque (anche `null`): il confronto con l'originale l'ha già fatto il dettaglio.
    mutating func adminExtractionSet(_ key: String, _ newValue: AriaJSON) {
        value(key, newValue, was: newValue == .null ? .bool(false) : .null)
    }
}

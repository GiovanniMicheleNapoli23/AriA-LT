//
//  AdminInspectionDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un'ispezione, come /inspections/{id} della web. La checklist si compila sul posto:
//  spunta e nota partono subito sullo schermo e vanno al server (PATCH per item); se il server rifiuta,
//  l'item torna com'era e si dice perché. Un item con una richiesta in corso non si tocca finché non finisce.
//  Qui anche il cambio di stato, l'eliminazione e l'applicazione della proposta dell'AI.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminInspectionDetailViewModel {
    let backend: AriaBackend
    private(set) var inspection: AdminInspection

    /// Id degli item con una richiesta in corso.
    private(set) var pendingItemIds: Set<String> = []
    private(set) var isLoading = false
    private(set) var isWorking = false
    private(set) var loadError: String?

    var actionError: String?
    var showsActionError = false
    var showsDeleteConfirmation = false
    var showsCompleteConfirmation = false

    @ObservationIgnored private let onChange: (AdminInspection) -> Void
    @ObservationIgnored private let onDelete: (String) -> Void

    init(backend: AriaBackend, inspection: AdminInspection,
         onChange: @escaping (AdminInspection) -> Void, onDelete: @escaping (String) -> Void) {
        self.backend = backend
        self.inspection = inspection
        self.onChange = onChange
        self.onDelete = onDelete
    }

    /// Senza id del server non si può scrivere niente.
    var canEdit: Bool { inspection.serverId != nil }
    var plantName: String? { inspection.plantId.flatMap { id in backend.plants.first { $0.id == id }?.name ?? id } }
    var transitions: [AdminInspectionTransition] { AdminInspectionTransition.available(from: inspection.knownStatus) }

    func canToggle(_ item: AdminInspectionItem) -> Bool {
        canEdit && item.serverId != nil && !pendingItemIds.contains(item.id)
    }

    // MARK: Caricamento

    func load() async {
        guard let id = inspection.serverId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await backend.api.call(AdminInspectionsAPI.detail(id: id))
            // Con una scrittura in corso la risposta potrebbe essere vecchia: la prossima lettura la prenderà.
            guard pendingItemIds.isEmpty, !isWorking else { return }
            adopt(fresh)
            loadError = nil
        } catch {
            if let message = AdminInspectionsFailure.message(for: error, backend: backend) { loadError = message }
        }
    }

    private func adopt(_ fresh: AdminInspection) {
        inspection = fresh
        onChange(fresh)
    }

    // MARK: Checklist

    func toggle(_ item: AdminInspectionItem) async {
        guard canToggle(item) else { return }
        let value = !item.isChecked
        await send(AdminInspectionItemChange(isChecked: value), to: item,
                   update: { $0.isChecked = value }, rollback: { $0.isChecked = !value })
    }

    func setNote(_ text: String, for item: AdminInspectionItem) async {
        guard canToggle(item) else { return }
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard note != (item.notes ?? "") else { return }
        let previous = item.notes
        await send(AdminInspectionItemChange(notes: note), to: item,
                   update: { $0.notes = note.isEmpty ? nil : note }, rollback: { $0.notes = previous })
    }

    /// Cambia l'item sullo schermo, poi lo manda: se fallisce lo rimette com'era.
    private func send(_ change: AdminInspectionItemChange, to item: AdminInspectionItem,
                      update: (inout AdminInspectionItem) -> Void, rollback: (inout AdminInspectionItem) -> Void) async {
        guard let inspectionId = inspection.serverId, let itemId = item.serverId else { return }
        edit(item.id, update)
        pendingItemIds.insert(item.id)
        defer { pendingItemIds.remove(item.id) }
        do {
            let fresh = try await backend.api.call(AdminInspectionsAPI.updateItem(inspectionId: inspectionId, itemId: itemId, change))
            // Il server può cambiare lo stato da solo (prima spunta = in corso): si prende quello.
            inspection.status = fresh.status
            inspection.completedAt = fresh.completedAt
            inspection.updatedAt = fresh.updatedAt ?? inspection.updatedAt
            onChange(inspection)
        } catch {
            edit(item.id, rollback)
            report(error)
        }
    }

    private func edit(_ itemId: String, _ change: (inout AdminInspectionItem) -> Void) {
        guard let index = inspection.items.firstIndex(where: { $0.id == itemId }) else { return }
        change(&inspection.items[index])
        onChange(inspection)
    }

    // MARK: Stato

    /// Completare con controlli ancora aperti chiede conferma.
    func requestTransition(_ transition: AdminInspectionTransition) async {
        if transition == .complete, inspection.uncheckedCount > 0 {
            showsCompleteConfirmation = true
        } else {
            await perform(transition)
        }
    }

    func perform(_ transition: AdminInspectionTransition) async {
        guard let id = inspection.serverId, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        var body = AdminPatchBody()
        body.value("status", .string(transition.target.rawValue), was: inspection.status.map(AriaJSON.string) ?? .null)
        switch transition {
        case .complete: body.value("completed_at", .string(Date.now.formatted(.iso8601)), was: .null)
        default: if inspection.completedAt != nil { body.value("completed_at", .null, was: .string("")) }
        }
        do {
            let updated = try await backend.api.call(AdminInspectionsAPI.update(id: id, body))
            adopt(merged(updated))
        } catch {
            report(error)
        }
    }

    // MARK: Eliminazione

    func delete() async -> Bool {
        guard let id = inspection.serverId, !isWorking else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await backend.api.call(AdminInspectionsAPI.delete(id: id))
            onDelete(inspection.id)
            return true
        } catch {
            report(error)
            return false
        }
    }

    // MARK: Dopo un salvataggio e AI

    /// Il form ha salvato: quello che torna è la verità.
    func saved(_ updated: AdminInspection) {
        adopt(merged(updated))
    }

    /// Una risposta senza item (server che li omette) non cancella la checklist a schermo.
    private func merged(_ fresh: AdminInspection) -> AdminInspection {
        var result = fresh
        if result.items.isEmpty, !inspection.items.isEmpty, result.serverId == inspection.serverId {
            result.items = inspection.items
        }
        return result
    }

    /// Applica la proposta dell'AI: note nuove e controlli in coda alla checklist. Gli item esistenti
    /// restano com'erano (spunte e note comprese). Torna il motivo dell'errore, `nil` se è andata bene.
    func applyAI(notes: String?, newItems: [String]) async -> String? {
        guard let id = inspection.serverId else { return AdminInspectionsFailure.roleMessage }
        var body = AdminPatchBody()
        if let notes { body.text("notes", notes, was: inspection.notes) }
        if !newItems.isEmpty {
            let start = (inspection.items.map(\.order).max() ?? -1) + 1
            let existing = inspection.items.map {
                AdminInspectionItemBody(id: $0.serverId ?? UUID().uuidString, order: $0.order, description: $0.description,
                                        isChecked: $0.isChecked, notes: $0.notes)
            }
            let added = newItems.enumerated().map { offset, text in
                AdminInspectionItemBody(id: UUID().uuidString, order: start + offset, description: text, isChecked: false, notes: nil)
            }
            body.value("items", .array((existing + added).map(\.json)), was: .null)
        }
        guard !body.isEmpty else { return nil }
        do {
            adopt(merged(try await backend.api.call(AdminInspectionsAPI.update(id: id, body))))
            return nil
        } catch {
            return AdminInspectionsFailure.message(for: error, backend: backend) ?? ""
        }
    }

    func makeAIViewModel() -> AdminInspectionAIViewModel {
        AdminInspectionAIViewModel(backend: backend, inspection: inspection) { [weak self] notes, items in
            await self?.applyAI(notes: notes, newItems: items)
        }
    }

    func makeFormViewModel() -> AdminInspectionFormViewModel {
        AdminInspectionFormViewModel(backend: backend, editing: inspection)
    }

    // MARK: Errori

    private func report(_ error: any Error) {
        guard let message = AdminInspectionsFailure.message(for: error, backend: backend) else { return }
        actionError = message
        showsActionError = true
    }
}

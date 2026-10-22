//
//  AdminWorkflowDetailViewModel+Actions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le azioni sul flusso: controlla, pubblica (prima controlla), duplica, archivia, ripristina l'archivio,
//  elimina. Tutte mandano la `revision` letta; se è cambiata (409) si dice e si ricarica il flusso.
//

import Foundation

extension AdminWorkflowDetailViewModel {
    /// Per `.alert` e `.confirmationDialog`: chiuderli azzera lo stato.
    var showsActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    var showsActionNotice: Bool {
        get { actionNotice != nil }
        set { if !newValue { actionNotice = nil } }
    }

    /// Pubblica ed elimina chiedono conferma qui; il ripristino la chiede il foglio delle versioni.
    var showsConfirmation: Bool {
        get {
            guard let pendingConfirmation else { return false }
            if case .restore = pendingConfirmation { return false }
            return true
        }
        set { if !newValue { pendingConfirmation = nil } }
    }

    var canPublish: Bool { flow.map { !$0.isArchived } ?? false }
    var canEdit: Bool { flow.map { !$0.isArchived } ?? false }

    func askToPublish() { pendingConfirmation = .publish }
    func askToDelete() { pendingConfirmation = .delete }

    /// Il pulsante del dialogo.
    func confirm(_ confirmation: AdminWorkflowConfirmation) async {
        pendingConfirmation = nil
        switch confirmation {
        case .publish: await publish()
        case .delete: await delete()
        case .restore(let version): _ = await restore(version)
        }
    }

    /// Apre il modulo di modifica di nome e descrizione; se la revisione è cambiata, rilegge il flusso.
    func startEditing() {
        guard let flow else { return }
        editForm = AdminWorkflowFormViewModel(backend: backend, editing: flow,
                                              reload: { [weak self] in await self?.refresh() })
    }

    func showVersions() { showsVersions = true }

    // MARK: Controllo

    func validate() async {
        guard let companyId = backend.activeCompanyId, flow != nil, !isValidating else { return }
        isValidating = true
        defer { isValidating = false }
        do {
            validation = try await backend.api.call(AdminWorkflowsAPI.validate(companyId: companyId, flowId: flowId))
        } catch {
            actionError = AdminWorkflowFailure.message(for: error, backend: backend)
        }
    }

    // MARK: Pubblica

    /// Controlla il flusso salvato e lo pubblica solo se non ha errori (gli avvisi non bloccano).
    /// La risposta del server è la versione, non il flusso: si rilegge per avere revisione e versione nuove.
    func publish() async {
        guard let companyId = backend.activeCompanyId, let flow, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await backend.api.call(AdminWorkflowsAPI.validate(companyId: companyId, flowId: flowId))
            validation = result
            guard result.valid else {
                actionError = String(localized: """
                    The flow has errors, so it wasn't published. \
                    The check results are below.
                    """)
                return
            }
            let version = try await backend.api.call(
                AdminWorkflowsAPI.publish(companyId: companyId, flowId: flowId, revision: flow.revision))
            await refresh()
            actionNotice = String(localized: "Published as version \(version.version).")
        } catch {
            await fail(error)
        }
    }

    // MARK: Stato e copia

    func archive() async {
        _ = await mutate { AdminWorkflowsAPI.archive(companyId: $0, flowId: $1, revision: $2) }
    }

    func unarchive() async {
        _ = await mutate { AdminWorkflowsAPI.unarchive(companyId: $0, flowId: $1, revision: $2) }
    }

    func duplicate() async {
        guard let companyId = backend.activeCompanyId, flow != nil, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let copy = try await backend.api.call(
                AdminWorkflowsAPI.duplicate(companyId: companyId, flowId: flowId, name: nil))
            list.apply(copy)
            actionNotice = String(localized: "Created a copy: \(copy.name)")
        } catch {
            await fail(error)
        }
    }

    // MARK: Elimina

    private func delete() async {
        guard let companyId = backend.activeCompanyId, flow != nil, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await backend.api.call(AdminWorkflowsAPI.delete(companyId: companyId, flowId: flowId))
            removed()
        } catch {
            // Già sparito sul server: per la lista è come averlo eliminato.
            if AdminWorkflowFailure.isNotFound(error) { removed() } else { await fail(error) }
        }
    }

    private func removed() {
        list.remove(id: flowId)
        flow = nil
    }

    // MARK: Comuni

    /// Un'azione che manda la revisione e risponde col flusso aggiornato.
    func mutate(_ request: (String, String, Int) -> AriaEndpoint<AdminWorkflow>) async -> AdminWorkflow? {
        guard let companyId = backend.activeCompanyId, let flow, !isBusy else { return nil }
        isBusy = true
        defer { isBusy = false }
        do {
            let updated = try await backend.api.call(request(companyId, flowId, flow.revision))
            didUpdate(updated)
            return updated
        } catch {
            await fail(error)
            return nil
        }
    }

    /// Un flusso nuovo da un'azione o dal modulo di modifica.
    func didUpdate(_ updated: AdminWorkflow) {
        flow = updated
        list.apply(updated)
    }

    /// Conflitto di revisione: si dice e si ricarica. Flusso sparito: si esce. Il resto è un avviso.
    func fail(_ error: any Error) async {
        if AdminWorkflowFailure.isConflict(error) {
            actionError = AdminWorkflowFailure.conflictMessage
            validation = nil
            await refresh()
        } else if AdminWorkflowFailure.isNotFound(error) {
            removed()
        } else {
            actionError = AdminWorkflowFailure.message(for: error, backend: backend)
        }
    }
}

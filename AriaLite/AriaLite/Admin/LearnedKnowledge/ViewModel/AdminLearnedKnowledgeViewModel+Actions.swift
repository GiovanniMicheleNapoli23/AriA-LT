//
//  AdminLearnedKnowledgeViewModel+Actions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Moderazione (PATCH: approva, rifiuta), eliminazione e aggiornamento della lista dopo una modifica.
//  Le usano sia la lista (menu della scheda) sia il dettaglio: il fatto aggiornato vale per entrambi.
//

import Foundation

extension AdminLearnedKnowledgeViewModel {
    /// Per `.alert`: chiuderli azzera lo stato.
    var showsActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    var showsActionNotice: Bool {
        get { actionNotice != nil }
        set { if !newValue { actionNotice = nil } }
    }

    var showsConfirmation: Bool {
        get { pendingConfirmation != nil }
        set { if !newValue { pendingConfirmation = nil } }
    }

    func isBusy(_ fact: AdminMemoryFact) -> Bool { busyFactIds.contains(fact.id) }

    func canApprove(_ fact: AdminMemoryFact) -> Bool { fact.knownStatus?.canApprove ?? true }
    func canReject(_ fact: AdminMemoryFact) -> Bool { fact.knownStatus?.canReject ?? true }

    // MARK: Moderazione

    func approve(_ fact: AdminMemoryFact) async {
        await moderate(fact, AdminMemoryFactModeration(action: .approve))
    }

    /// Il rifiuto passa dal dialogo di conferma.
    func askToReject(_ fact: AdminMemoryFact) { pendingConfirmation = .reject(fact) }
    func askToDelete(_ fact: AdminMemoryFact) { pendingConfirmation = .delete(fact) }

    /// Il pulsante del dialogo.
    func confirm(_ confirmation: AdminMemoryFactConfirmation) async {
        pendingConfirmation = nil
        switch confirmation {
        case .reject(let fact): await moderate(fact, AdminMemoryFactModeration(action: .reject))
        case .delete(let fact): await delete(fact)
        }
    }

    private func moderate(_ fact: AdminMemoryFact, _ body: AdminMemoryFactModeration) async {
        guard let companyId = backend.activeCompanyId, !isBusy(fact) else { return }
        busyFactIds.insert(fact.id)
        defer { busyFactIds.remove(fact.id) }
        do {
            apply(try await backend.api.call(AdminLearnedKnowledgeAPI.moderate(companyId: companyId, factId: fact.id, body)))
        } catch {
            actionError = AdminLearnedKnowledgeFailure.message(for: error, backend: backend)
        }
    }

    private func delete(_ fact: AdminMemoryFact) async {
        guard let companyId = backend.activeCompanyId, !isBusy(fact) else { return }
        busyFactIds.insert(fact.id)
        defer { busyFactIds.remove(fact.id) }
        do {
            _ = try await backend.api.call(AdminLearnedKnowledgeAPI.delete(companyId: companyId, factId: fact.id))
            removeFact(id: fact.id)
        } catch {
            // Già sparito sul server: per la lista è come averlo eliminato.
            if case .http(let status, _)? = error as? AriaError, status == 404 {
                removeFact(id: fact.id)
            } else {
                actionError = AdminLearnedKnowledgeFailure.message(for: error, backend: backend)
            }
        }
    }

    private func removeFact(id: String) {
        if facts.contains(where: { $0.id == id }) { total = total.map { max($0 - 1, 0) } }
        facts.removeAll { $0.id == id }
        knownFacts[id] = nil
        translations[id] = nil
    }

    // MARK: Dopo una modifica

    /// Un fatto creato, modificato o moderato: si aggiorna la lista senza ricaricarla.
    /// Se ora ha un altro stato da quello filtrato, esce dalla lista (il dettaglio lo vede ancora).
    func apply(_ fact: AdminMemoryFact) {
        let previous = knownFacts[fact.id]
        knownFacts[fact.id] = fact
        if let index = facts.firstIndex(where: { $0.id == fact.id }) {
            if matchesStatusFilter(fact) {
                facts[index] = fact
            } else {
                facts.remove(at: index)
                total = total.map { max($0 - 1, 0) }
            }
        } else if matchesStatusFilter(fact) {
            facts.insert(fact, at: 0)
            total = total.map { $0 + 1 }
        }
        refreshTranslation(of: fact, previous: previous)
    }

    /// Dal foglio "New fact". Un doppione torna come il fatto già noto, rinforzato: lo si dice.
    func didCreate(_ fact: AdminMemoryFact) {
        let existed = knownFacts[fact.id] != nil
        apply(fact)
        if existed {
            actionNotice = String(localized: "Aria already knew this fact: it has been reinforced instead of duplicated.")
        } else {
            requestTranslations(for: [fact])
        }
    }

    func makeEditForm(for fact: AdminMemoryFact) -> AdminMemoryFactFormViewModel {
        AdminMemoryFactFormViewModel(backend: backend, editing: fact)
    }
}

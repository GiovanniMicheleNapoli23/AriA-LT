//
//  AdminWorkflowDetailViewModel+Versions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le versioni pubblicate di un flusso: l'elenco (la più recente per prima) e il ripristino di una,
//  che riporta il grafo del flusso a com'era (dopo conferma, nel foglio delle versioni).
//

import Foundation

extension AdminWorkflowDetailViewModel {
    /// Per il dialogo di conferma del foglio delle versioni.
    var showsRestoreConfirmation: Bool {
        get {
            guard let pendingConfirmation else { return false }
            if case .restore = pendingConfirmation { return true }
            return false
        }
        set { if !newValue { pendingConfirmation = nil } }
    }

    var showsVersionsError: Bool {
        get { versionsError != nil }
        set { if !newValue { versionsError = nil } }
    }

    func askToRestore(_ version: AdminWorkflowVersion) { pendingConfirmation = .restore(version) }

    /// La versione che il flusso ha adesso: non ha senso ripristinarla.
    func isCurrent(_ version: AdminWorkflowVersion) -> Bool { flow?.definitionVersion == version.version }

    func loadVersions() async {
        guard let companyId = backend.activeCompanyId, !isLoadingVersions else { return }
        isLoadingVersions = true
        defer { isLoadingVersions = false }
        do {
            let rows = try await backend.api.call(AdminWorkflowsAPI.versions(companyId: companyId, flowId: flowId))
            versions = rows.items.sorted { $0.version > $1.version }
            versionsLoaded = true
        } catch {
            if let message = AdminWorkflowFailure.message(for: error, backend: backend) { versionsError = message }
        }
    }

    /// `true` se il flusso è stato riportato alla versione (il foglio si chiude).
    func restore(_ version: AdminWorkflowVersion) async -> Bool {
        guard let companyId = backend.activeCompanyId, let flow, !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        do {
            let updated = try await backend.api.call(AdminWorkflowsAPI.restore(
                companyId: companyId, flowId: flowId, version: version.version, revision: flow.revision))
            didUpdate(updated)
            validation = nil
            restoredVersion = version.version
            return true
        } catch {
            // Gli errori del foglio si mostrano nel foglio: sotto di lui un avviso non si vedrebbe.
            if AdminWorkflowFailure.isConflict(error) {
                versionsError = AdminWorkflowFailure.conflictMessage
                await refresh()
            } else {
                versionsError = AdminWorkflowFailure.message(for: error, backend: backend)
            }
            return false
        }
    }

    /// A foglio chiuso: l'avviso del ripristino riuscito.
    func announceRestoredVersion() {
        guard let number = restoredVersion else { return }
        restoredVersion = nil
        actionNotice = String(localized: "Restored version \(number). Publish it again when you're ready.")
    }
}

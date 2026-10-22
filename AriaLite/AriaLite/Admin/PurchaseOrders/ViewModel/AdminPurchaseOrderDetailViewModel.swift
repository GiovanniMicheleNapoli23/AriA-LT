//
//  AdminPurchaseOrderDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un ordine di acquisto: righe, approvazione, rifiuto, ricezione, modifica ed eliminazione.
//  L'ordine passato è un seme mostrato subito: all'apertura si rilegge dal server. Ogni ordine che il server
//  cambia passa da `apply(_:)`, che aggiorna la schermata e avvisa la lista. Azioni e conferme stanno in
//  `+Actions`, i valori da mostrare in `+Display`.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminPurchaseOrderDetailViewModel {
    let backend: AriaBackend
    let lookups: AdminPurchaseOrderLookups
    /// I ricambi dello stabilimento: nomi accanto ai codici e selettore del modulo di una riga.
    let spareParts: AdminPurchaseOrderLineParts
    private(set) var order: AdminPurchaseOrder
    let onChanged: (AdminPurchaseOrder) -> Void
    let onDeleted: (String) -> Void

    // MARK: - Stato

    private(set) var isRefreshing = false
    /// L'ordine non c'è sul server (senza id, o 404): niente azioni, solo la spiegazione.
    private(set) var isUnavailable: Bool
    /// L'aggiornamento non è arrivato: la scheda è quella dell'elenco (banner).
    private(set) var failure: AdminPurchaseOrdersFailure?
    /// I nomi dei membri già risolti (id → nome), per "approvato da".
    private(set) var memberNames: [String: String] = [:]

    /// L'azione in corso: una alla volta, gli altri pulsanti restano spenti.
    var runningAction: AdminPurchaseOrderDetailAction?
    var pendingConfirmation: AdminPurchaseOrderDetailConfirmation?
    /// Errore di un'azione (alert).
    var actionError: String?
    /// L'ordine è stato eliminato: la vista lo osserva e torna indietro.
    var didDelete = false
    var editForm: AdminPurchaseOrderFormViewModel?
    var lineForm: AdminPurchaseOrderLineFormViewModel?

    init(backend: AriaBackend, order: AdminPurchaseOrder, lookups: AdminPurchaseOrderLookups,
         onChanged: @escaping (AdminPurchaseOrder) -> Void, onDeleted: @escaping (String) -> Void) {
        self.backend = backend
        self.order = order
        self.lookups = lookups
        self.spareParts = AdminPurchaseOrderLineParts(backend: backend)
        self.onChanged = onChanged
        self.onDeleted = onDeleted
        self.isUnavailable = order.id.isEmpty
    }

    var api: AdminPurchaseOrdersAPI { AdminPurchaseOrdersAPI(api: backend.api) }

    // MARK: - Caricamento

    func load() async {
        guard !isUnavailable else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        async let lookupsLoad: Void = lookups.refreshIfStale()
        async let partsLoad: Void = spareParts.loadIfNeeded(plantId: order.plantId)
        await refetch()
        await resolveApprover()
        _ = await (lookupsLoad, partsLoad)
    }

    /// Rilegge l'ordine; `true` se è arrivato. Un 404 spegne la schermata, un altro errore la lascia com'è.
    @discardableResult
    func refetch(reportsFailure: Bool = true) async -> Bool {
        do {
            apply(try await api.order(id: order.id))
            failure = nil
            return true
        } catch {
            if Self.isNotFound(error) { markUnavailable() }
            if reportsFailure,
               let failure = AdminPurchaseOrdersFailure.from(error, action: .read, backend: backend) {
                self.failure = failure
            }
            return false
        }
    }

    /// L'unico punto in cui un ordine cambiato dal server entra nella schermata: la lista ne è avvisata.
    func apply(_ updated: AdminPurchaseOrder) {
        order = updated
        onChanged(updated)
    }

    /// La risposta di approva, rifiuta, ricevi o modifica: se arriva senza righe mentre l'ordine ne ha, si tengono
    /// quelle che ci sono (le righe non cambiano con queste azioni). Poi chi chiama rilegge l'ordine dal server.
    func applyServerResponse(_ response: AdminPurchaseOrder) {
        var merged = response
        if merged.lines.isEmpty, !order.lines.isEmpty { merged.lines = order.lines }
        apply(merged)
    }

    /// Cambia l'ordine solo qui (per esempio una riga appena aggiunta o tolta, in attesa della rilettura).
    func applyLocally(_ transform: (inout AdminPurchaseOrder) -> Void) {
        var copy = order
        transform(&copy)
        apply(copy)
    }

    // MARK: - Chi ha approvato

    /// Il nome di chi ha approvato: l'utente stesso, un membro già letto, altrimenti l'id grezzo.
    var approverName: String? {
        guard let id = order.approvedBy, !id.isEmpty else { return nil }
        if let account = backend.mobileAccount, account.id == id, !account.name.isEmpty { return account.name }
        return memberNames[id] ?? id
    }

    func resolveApprover() async {
        guard let id = order.approvedBy, !id.isEmpty, memberNames[id] == nil,
              backend.mobileAccount?.id != id else { return }
        if let name = try? await api.member(userId: id).displayName { memberNames[id] = name }
    }

    /// L'ordine non esiste più sul server: si spiega e si spengono le azioni.
    func markUnavailable() {
        isUnavailable = true
        failure = AdminPurchaseOrdersFailure(message: String(localized: "This purchase order no longer exists."),
                                            isForbidden: false)
    }

    nonisolated static func isNotFound(_ error: any Error) -> Bool {
        if case .http(404, _)? = error as? AriaError { return true }
        return false
    }
}

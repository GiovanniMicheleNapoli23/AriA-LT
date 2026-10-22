//
//  AdminPurchaseOrderDetailViewModel+Actions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le azioni del dettaglio: quali sono visibili e attive per lo stato dell'ordine, la conferma, la chiamata
//  e il suo esito. Una alla volta: finché una chiamata gira, tutte le altre sono spente.
//

import Foundation

extension AdminPurchaseOrderDetailViewModel {
    // MARK: - Quali azioni

    var isBusy: Bool { runningAction != nil }

    func isRunning(_ action: AdminPurchaseOrderDetailAction) -> Bool { runningAction == action }

    private var status: AdminPurchaseOrderStatus { order.statusKind }

    var canApprove: Bool { !isUnavailable && status.canApprove }
    var canReject: Bool { !isUnavailable && status.canReject }
    var canReceive: Bool { !isUnavailable && status.canReceive }
    var canEdit: Bool { !isUnavailable && status.isEditable }
    var canEditLines: Bool { canEdit }

    /// Un ordine già ordinato, approvato o ricevuto ha mosso soldi e magazzino: non si elimina da qui.
    var canDelete: Bool {
        guard !isUnavailable else { return false }
        switch status {
        case .draft, .pendingApproval, .rejected, .cancelled, .unknown: return true
        case .approved, .ordered, .partiallyReceived, .received: return false
        }
    }

    /// Approvare serve l'id dell'utente (`approved_by`): senza, il pulsante resta spento e si spiega perché.
    var currentUserId: String? {
        guard let id = backend.mobileAccount?.id, !id.isEmpty else { return nil }
        return id
    }

    var canApproveNow: Bool { canApprove && currentUserId != nil && !isBusy }
    var approveBlockedHint: String? {
        guard canApprove, currentUserId == nil else { return nil }
        return String(localized: "Approving needs your user account. Sign out and sign in again.")
    }

    /// Almeno un pulsante nella barra in basso (approva, rifiuta, ricevi).
    var hasPrimaryActions: Bool { canApprove || canReject || canReceive }

    // MARK: - Conferma

    var isConfirming: Bool {
        get { pendingConfirmation != nil }
        set { if !newValue { pendingConfirmation = nil } }
    }

    var isShowingActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    func ask(_ confirmation: AdminPurchaseOrderDetailConfirmation) {
        guard !isBusy else { return }
        pendingConfirmation = confirmation
    }

    func askToRemove(lineId: String) {
        guard canEditLines, let line = order.lines.first(where: { $0.id == lineId }) else { return }
        ask(.removeLine(id: lineId, name: lineDisplays.first { $0.id == lineId }?.title ?? line.partCode ?? ""))
    }

    func confirm(_ confirmation: AdminPurchaseOrderDetailConfirmation) async {
        pendingConfirmation = nil
        switch confirmation {
        case .approve: await approve()
        case .reject: await reject()
        case .receive: await receive()
        case .delete: await delete()
        case .removeLine(let id, _): await removeLine(id: id)
        }
    }

    // MARK: - Chiamate

    /// Esegue la chiamata di un'azione e gestisce l'errore; `nil` se è fallita.
    private func run<Result>(_ action: AdminPurchaseOrderDetailAction,
                             _ call: () async throws -> Result) async -> Result? {
        guard !isBusy else { return nil }
        runningAction = action
        defer { runningAction = nil }
        do {
            return try await call()
        } catch {
            if Self.isNotFound(error) { markUnavailable() }
            if let failure = AdminPurchaseOrdersFailure.from(error, action: .write, backend: backend) {
                actionError = failure.message
            }
            return nil
        }
    }

    private func approve() async {
        guard let userId = currentUserId else { return }
        let id = order.id
        if let approved = await run(.approve, { try await api.approve(id: id, approvedBy: userId) }) {
            applyServerResponse(approved)
            await resolveApprover()
            await refetch(reportsFailure: false)
        }
    }

    private func reject() async {
        let id = order.id
        if let rejected = await run(.reject, { try await api.reject(id: id) }) {
            applyServerResponse(rejected)
            await refetch(reportsFailure: false)
        }
    }

    private func receive() async {
        let id = order.id
        if let received = await run(.receive, { try await api.receive(id: id) }) {
            applyServerResponse(received)
            await refetch(reportsFailure: false)
        }
    }

    private func delete() async {
        let id = order.id
        guard await run(.delete, { try await api.delete(id: id) }) != nil else { return }
        onDeleted(id)
        didDelete = true
    }

    // MARK: - Righe

    func startAddingLine() {
        guard canEditLines, !isBusy else { return }
        lineForm = AdminPurchaseOrderLineFormViewModel(
            orderId: order.id, plantId: order.plantId, parts: spareParts, backend: backend
        ) { [weak self] line in
            await self?.didAdd(line)
        }
    }

    /// La risposta è solo la riga: la si aggiunge subito e si rilegge l'ordine per i totali.
    private func didAdd(_ line: AdminPurchaseOrderLine) async {
        applyLocally { $0.lines.append(line) }
        await refetch(reportsFailure: false)
    }

    private func removeLine(id lineId: String) async {
        let orderId = order.id
        guard await run(.removeLine(lineId), { try await api.removeLine(orderId: orderId, lineId: lineId) }) != nil
        else { return }
        applyLocally { $0.lines.removeAll { $0.id == lineId } }
        await refetch(reportsFailure: false)
    }

    // MARK: - Modifica

    func startEditing() {
        guard canEdit, !isBusy else { return }
        // I fornitori possono essere cambiati dalla sezione Fornitori: li si riaggiorna per il selettore del modulo.
        Task { await lookups.refreshIfStale() }
        editForm = AdminPurchaseOrderFormViewModel(mode: .edit(order), backend: backend, lookups: lookups) { [weak self] saved in
            guard let self else { return }
            applyServerResponse(saved)
            Task { await self.refetch(reportsFailure: false) }
        }
    }
}

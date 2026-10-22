//
//  AdminWorkOrderQuickActions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le azioni rapide su un ordine, uguali nella lista (swipe e menu contestuale) e nel dettaglio (menu di stato):
//  cambio di stato con PATCH `status`, "Complete" con le note (POST /complete), annullamento con conferma e
//  assegnazione automatica (POST /auto-assign) con l'esito in un avviso.
//

import Foundation
import Observation

/// Un avviso dopo un'azione: esito dell'assegnazione automatica o errore.
nonisolated struct AdminWorkOrderActionOutcome: Identifiable, Hashable, Sendable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
@Observable
final class AdminWorkOrderQuickActions {
    private let backend: AriaBackend
    /// L'ordine come l'ha salvato il server.
    @ObservationIgnored var onUpdated: (AdminWorkOrder) -> Void = { _ in }
    /// Dopo l'assegnazione automatica: l'ordine si rilegge (la risposta non lo porta).
    @ObservationIgnored var onReload: (String) async -> Void = { _ in }
    /// Dal dettaglio: "Complete" rifiutato per passi senza risultato porta alla scheda dei passi.
    @ObservationIgnored var showSteps: (() -> Void)?

    /// Ordini con una richiesta in volo: le loro azioni si disattivano.
    private(set) var busyIds: Set<String> = []
    /// Il foglio delle note di chiusura.
    var completion: AdminWorkOrderCompletionViewModel?
    /// L'ordine da annullare, in attesa di conferma.
    var cancelling: AdminWorkOrder?
    var outcome: AdminWorkOrderActionOutcome?

    init(backend: AriaBackend) {
        self.backend = backend
    }

    private var api: AdminWorkOrdersAPI { AdminWorkOrdersAPI(api: backend.api) }

    func reset() {
        busyIds = []
        completion = nil
        cancelling = nil
        outcome = nil
    }

    func isBusy(_ order: AdminWorkOrder) -> Bool { busyIds.contains(order.id) }

    var isShowingOutcome: Bool {
        get { outcome != nil }
        set { if !newValue { outcome = nil } }
    }

    var isConfirmingCancel: Bool {
        get { cancelling != nil }
        set { if !newValue { cancelling = nil } }
    }

    // MARK: Scelte

    /// Gli stati in cui si può portare l'ordine: tutti tranne quello attuale. "Verified" solo dopo il completamento.
    func statusChoices(for order: AdminWorkOrder) -> [AdminWorkOrderStatus] {
        AdminWorkOrderStatus.known.filter { status in
            status != order.status && (status != .verified || order.status == .completed)
        }
    }

    /// Swipe da sinistra: "Start" per un ordine non iniziato, "Hold" per uno in corso.
    func leadingSwipe(for order: AdminWorkOrder) -> AdminWorkOrderStatus? {
        switch order.status {
        case .proposed?, .planned?, .assigned?, nil, .unknown?: .inProgress
        case .inProgress?: holdStatus(for: order)
        case .completed?, .verified?, .cancelled?: nil
        }
    }

    /// Lo stato non ha "in pausa": un ordine fermato torna assegnato se ha chi lo esegue, altrimenti pianificato.
    func holdStatus(for order: AdminWorkOrder) -> AdminWorkOrderStatus {
        order.assignedToUserId != nil || order.assignedToTeamId != nil || order.assignedTo != nil ? .assigned : .planned
    }

    /// Swipe da destra: "Complete" per un ordine aperto.
    func canComplete(_ order: AdminWorkOrder) -> Bool { !order.isClosed }

    // MARK: Azioni

    /// Il punto d'ingresso di ogni cambio di stato: "Completed" chiede le note, "Cancelled" la conferma.
    func change(_ order: AdminWorkOrder, to status: AdminWorkOrderStatus) {
        switch status {
        case .completed: startCompleting(order)
        case .cancelled: cancelling = order
        case .unknown: break
        default: Task { await setStatus(order, status) }
        }
    }

    func startCompleting(_ order: AdminWorkOrder) {
        let showSteps = showSteps.map { open in
            { [weak self] in
                self?.completion = nil
                open()
            }
        }
        completion = AdminWorkOrderCompletionViewModel(order: order, backend: backend, showSteps: showSteps) { [weak self] done in
            self?.onUpdated(done)
        }
    }

    func confirmCancel() async {
        guard let order = cancelling else { return }
        cancelling = nil
        await setStatus(order, .cancelled)
    }

    func setStatus(_ order: AdminWorkOrder, _ status: AdminWorkOrderStatus) async {
        guard !isBusy(order), status != .unknown else { return }
        busyIds.insert(order.id)
        defer { busyIds.remove(order.id) }
        do {
            let saved = try await api.update(order.id, AdminWorkOrderUpdate(status: status.rawValue))
            onUpdated(saved)
        } catch {
            fail(error, title: String(localized: "Couldn't change the status"))
        }
    }

    func autoAssign(_ order: AdminWorkOrder) async {
        guard !isBusy(order) else { return }
        busyIds.insert(order.id)
        defer { busyIds.remove(order.id) }
        do {
            let result = try await api.autoAssign(order.id)
            outcome = Self.outcome(result)
            await onReload(order.id)
        } catch {
            fail(error, title: String(localized: "Couldn't auto-assign"))
        }
    }

    static func outcome(_ result: AdminWorkOrderAutoAssignResult) -> AdminWorkOrderActionOutcome {
        if result.assigned {
            let who = result.assigneeName ?? result.assigneeId ?? String(localized: "a technician")
            let text = String(localized: "Assigned to \(who).")
            return AdminWorkOrderActionOutcome(title: String(localized: "Auto-assigned"),
                                               message: [text, result.note].compactMap { $0 }.joined(separator: "\n"))
        }
        return AdminWorkOrderActionOutcome(
            title: String(localized: "Nobody available"),
            message: result.note ?? String(localized: "No technician could be picked. The current assignee stays.")
        )
    }

    private func fail(_ error: any Error, title: String) {
        guard let message = AdminWorkOrderFailure.message(for: error, backend: backend) else { return }
        outcome = AdminWorkOrderActionOutcome(title: title, message: message)
    }
}
